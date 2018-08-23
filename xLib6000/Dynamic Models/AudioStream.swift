//
//  AudioStream.swift
//  xLib6000
//
//  Created by Douglas Adams on 2/24/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

public typealias DaxStreamId = UInt32
public typealias DaxChannel = Int
public typealias DaxIqChannel = Int

// ------------------------------------------------------------------------------
// MARK: - AudioStream Class implementation
//
//      creates an AudioStream instance to be used by a Client to support the
//      processing of a stream of Audio from the Radio to the client. AudioStream
//      objects are added / removed by the incoming TCP messages. AudioStream
//      objects periodically receive Audio in a UDP stream.
//
// ------------------------------------------------------------------------------

public final class AudioStream              : NSObject, DynamicModelWithStream {

  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : DaxStreamId = 0               // The Audio stream id

  public private(set) var rxLostPacketCount = 0                             // Rx lost packet count

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue!                // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _rxSeq                        : Int?                          // Rx sequence number
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __daxChannel                  = 0                             // Channel in use (1 - 8)
  private var __daxClients                  = 0                             // Number of clients
  private var __inUse                       = false                         // true = in use
  private var __ip                          = ""                            // Ip Address
  private var __port                        = 0                             // Port number
  private var __rxGain                      = 50                            // rx gain of stream
  private var __slice                       : xLib6000.Slice?               // Source Slice
  //
  private weak var _delegate                : StreamHandler?                // Delegate for Audio stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse an AudioStream status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <streamId, > <"dax", channel> <"in_use", 1|0> <"slice", number> <"ip", ip> <"port", port>
    
    //get the AudioStreamId (remove the "0x" prefix)
    if let streamId =  UInt32(String(keyValues[0].key.dropFirst(2)), radix: 16) {
      
      // is the AudioStream in use?
      if inUse {
        
        // YES, does the AudioStream exist?
        if radio.audioStreams[streamId] == nil {
          
          // NO, is this stream for this client?
          if !AudioStream.isStatusForThisClient(keyValues) { return }
          
          // create a new AudioStream & add it to the AudioStreams collection
          radio.audioStreams[streamId] = AudioStream(id: streamId, queue: queue)
        }
        // pass the remaining key values to the AudioStream for parsing
        radio.audioStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
        
      } else {
        
        // does the stream exist?
        if let stream = radio.audioStreams[streamId] {
          
          // notify all observers
          NC.post(.audioStreamWillBeRemoved, object: stream as Any?)
          
          // remove the stream object
          radio.audioStreams[streamId] = nil
        }
      }
    }
  }
  /// Check if an Audio Stream belongs to us
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray of the status message
  ///
  /// - Returns:              result of the check
  ///
  public class func isStatusForThisClient(_ properties: KeyValuesArray) -> Bool {
    
    // allow a Tester app to see all Streams
    guard Api.sharedInstance.testerModeEnabled == false else { return true }
    
    var statusIpStr = ""
    var statusPortStr = ""
    
    // search thru each key/value pair, <key=value>
    for property in properties {
      
      switch property.key.lowercased() {
      case "ip":
        statusIpStr = property.value
      case "port":
        statusPortStr = property.value
      default:
        break
      }
    }
    
    if statusIpStr == "" || statusPortStr == "" {
      return false
    }
    if !statusIpStr.isValidIP4() {
      return false
    }
    guard let statusPort = UInt16(statusPortStr) else {
      return false
    }
    
    // if local check ip and port
    // if remote check only ip
    // TODO: this is a temporary fix and a flaw in Flex way to think.. :-)
    if Api.sharedInstance.isWan {
      if Api.sharedInstance.localIP == statusIpStr {
        return true
      }
    } else {
      if Api.sharedInstance.localIP == statusIpStr && Api.sharedInstance.localUDPPort == statusPort {
        return true
      }
    }
    
    return false
  }
  /// Find an AudioStream by DAX Channel
  ///
  /// - Parameter channel:    Dax channel number
  /// - Returns:              an AudioStream (if any)
  ///
  public class func find(with channel: DaxChannel) -> AudioStream? {
    
    // find the AudioStream with the specified Channel (if any)
    let streams = Api.sharedInstance.radio!.audioStreams.values.filter { $0.daxChannel == channel }
    guard streams.count >= 1 else { return nil }
    
    // return the first one
    return streams[0]
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an Audio Stream
  ///
  /// - Parameters:
  ///   - id:                 the Stream Id
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

  /// Parse Audio Stream key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown keys
      guard let token = Token(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .daxChannel:
        willChangeValue(for: \.daxChannel)
        _daxChannel = property.value.iValue()
        didChangeValue(for: \.daxChannel)

      case .daxClients:
        willChangeValue(for: \.daxClients)
        _daxClients = property.value.iValue()
        didChangeValue(for: \.daxClients)

      case .inUse:
        willChangeValue(for: \.inUse)
        _inUse = property.value.bValue()
        didChangeValue(for: \.inUse)

      case .ip:
        willChangeValue(for: \.ip)
        _ip = property.value
        didChangeValue(for: \.ip)

      case .port:
        willChangeValue(for: \.port)
        _port = property.value.iValue()
        didChangeValue(for: \.port)

      case .slice:
        willChangeValue(for: \.slice)
        _slice = _api.radio!.slices[property.value]
        didChangeValue(for: \.slice)

        let gain = _rxGain
        _rxGain = 0
        rxGain = gain
      }
    }    
    // if this is not yet initialized and inUse becomes true
    if !_initialized && _inUse && _ip != "" {
      
      // YES, the Radio (hardware) has acknowledged this Audio Stream
      _initialized = true
      
      // notify all observers
      NC.post(.audioStreamHasBeenAdded, object: self as Any?)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - VitaProcessor Protocol method
  
  //      called by Radio on the streamQ
  //
  //      The payload of the incoming Vita struct is converted to an AudioStreamFrame and
  //      passed to the Audio Stream Handler
  
  /// Process the AudioStream Vita struct
  ///
  /// - Parameters:
  ///   - vita:       a Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    if vita.classCode != .daxAudio {
      // not for us
      return
    }
    
    // if there is a delegate, process the Panadapter stream
    if let delegate = delegate {
      
      let payloadPtr = UnsafeRawPointer(vita.payloadData)
      
      // initialize a data frame
      var dataFrame = AudioStreamFrame(payload: payloadPtr, numberOfBytes: vita.payloadSize)
      
      dataFrame.daxChannel = self.daxChannel
      
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
// MARK: - AudioStreamFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Audio Stream vitaHandler
//

/// Struct containing Audio Stream data
///
public struct AudioStreamFrame {
  
  public var daxChannel                     = -1
  public private(set) var samples           = 0                             // number of samples (L/R) in this frame
  public var leftAudio                      = [Float]()                     // Array of left audio samples
  public var rightAudio                     = [Float]()                     // Array of right audio samples
  
  /// Initialize an AudioStreamFrame
  ///
  /// - Parameters:
  ///   - payload:        pointer to a Vita packet payload
  ///   - numberOfBytes:  number of bytes in the payload
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
// MARK: - AudioStream Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - AudioStream tokens
// --------------------------------------------------------------------------------

extension AudioStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _daxChannel: Int {
    get { return _q.sync { __daxChannel } }
    set { _q.sync(flags: .barrier) { __daxChannel = newValue } } }
  
  internal var _daxClients: Int {
    get { return _q.sync { __daxClients } }
    set { _q.sync(flags: .barrier) { __daxClients = newValue } } }
  
  internal var _inUse: Bool {
    get { return _q.sync { __inUse } }
    set { _q.sync(flags: .barrier) { __inUse = newValue } } }
  
  internal var _ip: String {
    get { return _q.sync { __ip } }
    set { _q.sync(flags: .barrier) { __ip = newValue } } }
  
  internal var _port: Int {
    get { return _q.sync { __port } }
    set { _q.sync(flags: .barrier) { __port = newValue } } }
  
  internal var _rxGain: Int {
    get { return _q.sync { __rxGain } }
    set { _q.sync(flags: .barrier) { __rxGain = newValue } } }
  
  internal var _slice: xLib6000.Slice? {
    get { return _q.sync { __slice } }
    set { _q.sync(flags: .barrier) { __slice = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var daxChannel: Int {
    get { return _daxChannel }
    set {
      if _daxChannel != newValue {
        _daxChannel = newValue
        if _api.radio != nil {
          slice = xLib6000.Slice.find(with: _daxChannel)
        }
      }
    }
  }
  
  @objc dynamic public var daxClients: Int {
    get { return _daxClients  }
    set { if _daxClients != newValue { _daxClients = newValue } } }
  
  @objc dynamic public var inUse: Bool {
    return _inUse }
  
  @objc dynamic public var ip: String {
    get { return _ip }
    set { if _ip != newValue { _ip = newValue } } }
  
  @objc dynamic public var port: Int {
    get { return _port  }
    set { if _port != newValue { _port = newValue } } }
  
  @objc dynamic public var slice: xLib6000.Slice? {
    get { return _slice }
    set { if _slice != newValue { _slice = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var delegate: StreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // Mark: - AudioStream tokens
  
  internal enum Token: String {
    case daxChannel                         = "dax"
    case daxClients                         = "dax_clients"
    case inUse                              = "in_use"
    case ip
    case port
    case slice
  }
}
