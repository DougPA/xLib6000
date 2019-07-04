//
//  MicAudioStream.swift
//  xLib6000
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa

/// MicAudioStream Class implementation
///
///      creates a MicAudioStream instance to be used by a Client to support the
///      processing of a stream of Mic Audio from the Radio to the client. MicAudioStream
///      objects are added / removed by the incoming TCP messages. MicAudioStream
///      objects periodically receive Mic Audio in a UDP stream.
///
public final class MicAudioStream           : NSObject, DynamicModelWithStream {
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var streamId          : DaxStreamId = 0               // Mic Audio streamId
  public var rxLostPacketCount              = 0                             // Rx lost packet count

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private var _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue                 // Q for object synchronization
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
  private weak var _delegate                : StreamHandler?                // Delegate for Audio stream
  //                                                                                                  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods
  
  /// Parse a Mic AudioStream status message
  ///
  ///   StatusParser Protocol method, executes on the parseQ
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
    if let streamId =  keyValues[0].key.streamId {
      
      // is the Stream in use?
      if inUse {
        
        // YES, does the MicAudioStream exist?
        if radio.micAudioStreams[streamId] == nil {
          
          // NO, is this stream for this client?
          if !AudioStream.isStatusForThisClient(keyValues) { return }
          
          // create a new MicAudioStream & add it to the MicAudioStreams collection
          radio.micAudioStreams[streamId] = MicAudioStream(streamId: streamId, queue: queue)
        }
        // pass the remaining key values to the MicAudioStream for parsing (dropping the Id)
        radio.micAudioStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
        
      } else {
        
        // does the stream exist?
        if let stream = radio.micAudioStreams[streamId] {
          
          // notify all observers
          NC.post(.micAudioStreamWillBeRemoved, object: stream as Any?)
          
          // remove the stream object
          radio.micAudioStreams[streamId] = nil
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an Mic Audio Stream
  ///
  /// - Parameters:
  ///   - id:                 a Dax Stream Id
  ///   - queue:              Concurrent queue
  ///
  init(streamId: DaxStreamId, queue: DispatchQueue) {
    
    self.streamId = streamId
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods

  /// Parse Mic Audio Stream key/value pairs
  ///
  ///   PropertiesParser Protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        // log it and ignore the Key
        _log.msg("Unknown MicAudioStream token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .inUse:
        willChangeValue(for: \.inUse)
        _inUse = property.value.bValue
        didChangeValue(for: \.inUse)

      case .ip:
        willChangeValue(for: \.ip)
        _ip = property.value
        didChangeValue(for: \.ip)

      case .port:
        willChangeValue(for: \.port)
        _port = property.value.iValue
        didChangeValue(for: \.port)

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
  /// Process the Mic Audio Stream Vita struct
  ///
  ///   VitaProcessor protocol method, executes on the streamQ
  ///      The payload of the incoming Vita struct is converted to a MicAudioStreamFrame and
  ///      passed to the Mic Audio Stream Handler, called by Radio
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
      _log.msg("Missing AudioStream packet(s), rcvdSeq: \(vita.sequence),  != expectedSeq: \(expectedSequenceNumber)", level: .debug, function: #function, file: #file, line: #line)

      _rxSeq = nil
      rxLostPacketCount += 1
    } else {
      
      _rxSeq = expectedSequenceNumber
    }
  }
}

extension MicAudioStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
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
  // MARK: - Public properties (KVO compliant)
  
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
  // MARK: - NON Public properties (KVO compliant)
  
  public var delegate: StreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum Token: String {
    case inUse      = "in_use"
    case ip
    case port
  }
}
