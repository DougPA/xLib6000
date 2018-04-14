//
//  MicAudioStream.swift
//  xLib6000
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa

// --------------------------------------------------------------------------------
// MARK: - MicAudioStreamHandler protocol
//
// --------------------------------------------------------------------------------

public protocol MicAudioStreamHandler       : class {
  
  /// Method to process a Mic Audio stream (audio to the mic)
  ///
  /// - Parameter frame:          a MicAudioStreamFrame struct
  ///
  func streamHandler(_ frame: MicAudioStreamFrame)
}

// ------------------------------------------------------------------------------
// MARK: - MicAudioStream Class implementation
//
//      creates a MicAudioStream instance to be used by a Client to support the
//      processing of a stream of Mic Audio from the Radio to the client. MicAudioStream
//      objects are added / removed by the incoming TCP messages. MicAudioStream
//      objects periodically receive Mic Audio in a UDP stream.
//
// ------------------------------------------------------------------------------

public final class MicAudioStream           : NSObject, StatusParser, PropertiesParser, VitaProcessor {
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : DaxStreamId = 0               // The Mic Audio stream id

  public var rxLostPacketCount              = 0                             // Rx lost packet count

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware
  
  private var _rxSeq                        : Int?                          // Rx sequence number
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __inUse                       = false                         // true = in use
  private var __ip                          = ""                            // Ip Address
  private var __port                        = 0                             // Port number
  private var __micGain                     = 50                            // rx gain of stream
  private var __micGainScalar               : Float = 1.0                   // scalar gain value for multiplying
  //
  private weak var _delegate                : MicAudioStreamHandler?        // Delegate for Audio stream
  //                                                                                                  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ----------------------------------------------------------------------------
  // MARK: - StatusParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a Mic AudioStream status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <streamId, > <"in_use", 1|0> <"ip", ip> <"port", port>
    
    //get the MicAudioStreamId (remove the "0x" prefix)
    if let streamId =  UInt32(String(keyValues[0].key.dropFirst(2)), radix: 16) {
      
      // is the Stream in use?
      if inUse {
        
        // YES, does the MicAudioStream exist?
        if radio.micAudioStreams[streamId] == nil {
          
          // NO, is this stream for this client?
          if !radio.isAudioStreamStatusForThisClient(keyValues) { return }
          
          // create a new MicAudioStream & add it to the MicAudioStreams collection
          radio.micAudioStreams[streamId] = MicAudioStream(id: streamId, queue: queue)
        }
        // pass the remaining key values to the MicAudioStream for parsing (dropping the Id)
        radio.micAudioStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
        
      } else {
        
        // NO, notify all observers
        NC.post(.micAudioStreamWillBeRemoved, object: radio.micAudioStreams[streamId] as Any?)
        
        // remove it
        radio.micAudioStreams[streamId] = nil
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an Mic Audio Stream
  ///
  /// - Parameters:
  ///   - id:                 a Dax Stream Id
  ///   - radio:              the Radio instance
  ///   - queue:              Concurrent queue
  ///
  init(id: DaxStreamId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse Mic Audio Stream key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown keys
      guard let token = Token(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .inUse:
        willChangeValue(forKey: "inUse")
        _inUse = property.value.bValue()
        didChangeValue(forKey: "inUse")
        
      case .ip:
        willChangeValue(forKey: "ip")
        _ip = property.value
        didChangeValue(forKey: "ip")
        
      case .port:
        willChangeValue(forKey: "port")
        _port = property.value.iValue()
        didChangeValue(forKey: "port")
        
      }
    }
    // is the AudioStream acknowledged by the radio?
    if !_initialized && _inUse && _ip != "" {
      
      // YES, the Radio (hardware) has acknowledged this Audio Stream
      _initialized = true
      
      // notify all observers
      NC.post(.micAudioStreamHasBeenAdded, object: self as Any?)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - VitaProcessor protocol methods
  
  //      called by Radio on the streamQ
  //
  //      The payload of the incoming Vita struct is converted to a MicAudioStreamFrame and
  //      passed to the Mic Audio Stream Handler
  
  /// Process the Mic Audio Stream Vita struct
  ///
  /// - Parameters:
  ///   - vitaPacket:         a Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    if vita.classCode != .daxAudio {
      // not for us
      return
    }
    
    // if there is a delegate, process the Mic Audio stream
    if let delegate = delegate {
      
      let payloadPtr = UnsafeRawPointer(vita.payloadData)
      
      // initialize a data frame
      var dataFrame = MicAudioStreamFrame(payload: payloadPtr, numberOfBytes: vita.payloadSize)
      
      // get a pointer to the data in the payload
      let wordsPtr = payloadPtr.bindMemory(to: UInt32.self, capacity: dataFrame.samples * 2)
      
      // allocate temporary data arrays
      var dataLeft = [UInt32](repeating: 0, count: dataFrame.samples)
      var dataRight = [UInt32](repeating: 0, count: dataFrame.samples)
      
      // swap endianess on the bytes
      // for each sample if we are dealing with DAX audio
      
      // Swap the byte ordering of the samples & place it in the dataFrame left and right samples
      for i in 0..<dataFrame.samples {
        
        dataLeft[i] = CFSwapInt32BigToHost(wordsPtr.advanced(by: 2*i+0).pointee)
        dataRight[i] = CFSwapInt32BigToHost(wordsPtr.advanced(by: 2*i+1).pointee)
      }
      // copy the data as is -- it is already floating point
      memcpy(&(dataFrame.leftAudio), &dataLeft, dataFrame.samples * 4)
      memcpy(&(dataFrame.rightAudio), &dataRight, dataFrame.samples * 4)
      
      // scale with rx gain
      let scale = self._micGainScalar
      for i in 0..<dataFrame.samples {
        
        dataFrame.leftAudio[i] = dataFrame.leftAudio[i] * scale
        dataFrame.rightAudio[i] = dataFrame.rightAudio[i] * scale
      }
      
      // Pass the data frame to this AudioSream's delegate
      delegate.streamHandler(dataFrame)
    }
    
    // calculate the next Sequence Number
    let expectedSequenceNumber = (_rxSeq == nil ? vita.sequence : (_rxSeq! + 1) % 16)
    
    // is the received Sequence Number correct?
    if vita.sequence != expectedSequenceNumber {
      
      // NO, log the issue
      Log.sharedInstance.msg("Missing packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(expectedSequenceNumber)", level: .warning, function: #function, file: #file, line: #line)
      
      _rxSeq = nil
      rxLostPacketCount += 1
    } else {
      
      _rxSeq = expectedSequenceNumber
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - MicAudioStreamFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Mic Audio Stream vitaHandler
//

/// Struct containing Mic Audio Stream data
///
public struct MicAudioStreamFrame {
  
  public private(set) var samples           = 0                             // number of samples (L/R) in this frame
  public var leftAudio                      = [Float]()                     // Array of left audio samples
  public var rightAudio                     = [Float]()                     // Array of right audio samples
  
  /// Initialize a AudioStreamFrame
  ///
  /// - Parameters:
  ///   - payload:        pointer to a Vita packet payload
  ///   - numberOfWords:  number of 32-bit Words in the payload
  ///
  public init(payload: UnsafeRawPointer, numberOfBytes: Int) {
    
    // 4 byte each for left and right sample (4 * 2)
    self.samples = numberOfBytes / (4 * 2)
    
    // allocate the samples arrays
    self.leftAudio = [Float](repeating: 0, count: samples)
    self.rightAudio = [Float](repeating: 0, count: samples)
  }
}

// --------------------------------------------------------------------------------
// MARK: - MicAudioStream Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - MicAudioStream tokens
// --------------------------------------------------------------------------------

extension MicAudioStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _inUse: Bool {
    get { return _q.sync { __inUse } }
    set { _q.sync(flags: .barrier) { __inUse = newValue } } }
  
  internal var _ip: String {
    get { return _q.sync { __ip } }
    set { _q.sync(flags: .barrier) { __ip = newValue } } }
  
  internal var _port: Int {
    get { return _q.sync { __port } }
    set { _q.sync(flags: .barrier) { __port = newValue } } }
  
  internal var _micGain: Int {
    get { return _q.sync { __micGain } }
    set { _q.sync(flags: .barrier) { __micGain = newValue } } }
  
  internal var _micGainScalar: Float {
    get { return _q.sync { __micGainScalar } }
    set { _q.sync(flags: .barrier) { __micGainScalar = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var inUse: Bool {
    return _inUse }
  
  @objc dynamic public var ip: String {
    get { return _ip }
    set { if _ip != newValue { _ip = newValue } } }
  
  @objc dynamic public var port: Int {
    get { return _port  }
    set { if _port != newValue { _port = newValue } } }
  
  @objc dynamic public var micGain: Int {
    get { return _micGain  }
    set {
      if _micGain != newValue {
        let value = newValue.bound(0, 100)
        if _micGain != value {
          _micGain = value
          if _micGain == 0 {
            _micGainScalar = 0.0
            return
          }
          let db_min:Float = -10.0;
          let db_max:Float = +10.0;
          let db:Float = db_min + (Float(_micGain) / 100.0) * (db_max - db_min);
          _micGainScalar = pow(10.0, db / 20.0);
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var delegate: MicAudioStreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - MicAudioStream tokens
  
  internal enum Token: String {
    case inUse      = "in_use"
    case ip
    case port
  }
  
}
