//
//  IqStream.swift
//  xLib6000
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import os.log
import Accelerate

/// IqStream Class implementation
///
///      creates an IqStream instance to be used by a Client to support the
///      processing of a stream of IQ data from the Radio to the client. IqStream
///      objects are added / removed by the incoming TCP messages. IqStream
///      objects periodically receive IQ data in a UDP stream.
///
public final class IqStream                 : NSObject, DynamicModelWithStream {
 
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kCmd                           = "dax iq "                     // Command prefixes
  static let kStreamCreateCmd               = "stream create "
  static let kStreamRemoveCmd               = "stream remove "

  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : DaxStreamId = 0               // Stream Id
  public private(set) var rxLostPacketCount = 0                             // Rx lost packet count

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "IqStream")
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _rxSeq                        : Int?                          // Rx sequence number

  // see FlexLib
  private var _kOneOverZeroDBfs             : Float = 1.0 / pow(2.0, 15.0)
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -------
  //
  private var __available                   = 0                             // Number of available IQ Streams
  private var __capacity                    = 0                             // Total Number of  IQ Streams
  private var __daxIqChannel                : DaxIqChannel = 0              // Channel in use (1 - 4)
  private var __inUse                       = false                         // true = in use
  private var __ip                          = ""                            // Ip Address
  private var __pan                         : PanadapterId = 0              // Source Panadapter
  private var __port                        = 0                             // Port number
  private var __rate                        = 0                             // Stream rate
  private var __streaming                   = false                         // Stream state
  //
  private weak var _delegate                : StreamHandler?                // Delegate for IQ stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -------
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods

  /// Parse a Stream status message
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
    // Format: <streamId, > <"daxiq", value> <"pan", panStreamId> <"rate", value> <"ip", ip> <"port", port> <"streaming", 1|0> ,"capacity", value> <"available", value>
    
    //get the StreamId (remove the "0x" prefix)
    if let streamId =  UInt32(String(keyValues[0].key.dropFirst(2)), radix: 16) {
      
      // is the Stream in use?
      if inUse {
        
        // YES, does the Stream exist?
        if radio.iqStreams[streamId] == nil {
          
          // NO, is this stream for this client?
          if !AudioStream.isStatusForThisClient(keyValues) { return }
          
          // create a new Stream & add it to the Streams collection
          radio.iqStreams[streamId] = IqStream(id: streamId, queue: queue)
        }
        // pass the remaining key values to the IqStream for parsing (dropping the Id)
        radio.iqStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
        
      } else {
        
        // does the stream exist?
        if let stream = radio.iqStreams[streamId] {
          
          // notify all observers
          NC.post(.iqStreamWillBeRemoved, object: stream as Any?)
          
          // remove the stream object
          radio.iqStreams[streamId] = nil
        }
      }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  /// Find the IQ Stream for a DaxIqChannel
  ///
  /// - Parameters:
  ///   - daxIqChannel:   a Dax IQ channel number
  /// - Returns:          an IQ Stream reference (or nil)
  ///
  public class func findBy(daxIqChannel: DaxIqChannel) -> IqStream? {

    // find the IQ Streams with the specified Channel (if any)
    let streams = Api.sharedInstance.radio!.iqStreams.values.filter { $0.daxIqChannel == daxIqChannel }
    guard streams.count >= 1 else { return nil }
    
    // return the first one
    return streams[0]
  }

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an IQ Stream
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
  // MARK: - Protocol instance methods

  /// Parse IQ Stream key/value pairs
  ///
  ///   PropertiesParser Protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      guard let token = Token(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
        os_log("Unknown IqStream token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .available:
        willChangeValue(for: \.available)
        _available = property.value.iValue
        didChangeValue(for: \.available)

      case .capacity:
        willChangeValue(for: \.capacity)
        _capacity = property.value.iValue
        didChangeValue(for: \.capacity)

      case .daxIqChannel:
        willChangeValue(for: \.daxIqChannel)
        _daxIqChannel = property.value.iValue
        didChangeValue(for: \.daxIqChannel)

      case .inUse:
        willChangeValue(for: \.inUse)
        _inUse = property.value.bValue
        didChangeValue(for: \.inUse)

      case .ip:
        willChangeValue(for: \.ip)
        _ip = property.value
        didChangeValue(for: \.ip)

      case .pan:
        willChangeValue(for: \.pan)
        _pan = UInt32(property.value.dropFirst(2), radix: 16) ?? 0
        didChangeValue(for: \.pan)

      case .port:
        willChangeValue(for: \.port)
        _port = property.value.iValue
        didChangeValue(for: \.port)

      case .rate:
        willChangeValue(for: \.rate)
        _rate = property.value.iValue
        didChangeValue(for: \.rate)

      case .streaming:
        willChangeValue(for: \.streaming)
        _streaming = property.value.bValue
        didChangeValue(for: \.streaming)
      }
    }
    // is the Stream initialized?
    if !_initialized && _ip != "" {
      
      // YES, the Radio (hardware) has acknowledged this Stream
      _initialized = true
      
      // notify all observers
      NC.post(.iqStreamHasBeenAdded, object: self as Any?)
    }
  }
  /// Process the IqStream Vita struct
  ///
  ///   VitaProcessor Protocol method, executes on the streamQ
  ///      The payload of the incoming Vita struct is converted to an IqStreamFrame and
  ///      passed to the IQ Stream Handler, called by Radio
  ///
  /// - Parameters:
  ///   - vita:       a Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    // if there is a delegate, process the Panadapter stream
    if let delegate = delegate {
      
      let payloadPtr = UnsafeRawPointer(vita.payloadData)
      
      // initialize a data frame
      var dataFrame = IqStreamFrame(payload: payloadPtr, numberOfBytes: vita.payloadSize)
      
      dataFrame.daxIqChannel = self.daxIqChannel
      
      // get a pointer to the data in the payload
      let wordsPtr = payloadPtr.bindMemory(to: Float32.self, capacity: dataFrame.samples * 2)
      
      // allocate temporary data arrays
      var dataLeft = [Float32](repeating: 0, count: dataFrame.samples)
      var dataRight = [Float32](repeating: 0, count: dataFrame.samples)
      
      // FIXME: is there a better way
      // de-interleave the data
      for i in 0..<dataFrame.samples {
        
        dataLeft[i] = wordsPtr.advanced(by: (2*i)).pointee
        dataRight[i] = wordsPtr.advanced(by: (2*i) + 1).pointee
      }
      
      // copy & normalize the data
      vDSP_vsmul(&dataLeft, 1, &_kOneOverZeroDBfs, &(dataFrame.realSamples), 1, vDSP_Length(dataFrame.samples))
      vDSP_vsmul(&dataRight, 1, &_kOneOverZeroDBfs, &(dataFrame.imagSamples), 1, vDSP_Length(dataFrame.samples))
      
      // Pass the data frame to this AudioSream's delegate
      delegate.streamHandler(dataFrame)
    }
    
    // calculate the next Sequence Number
    let expectedSequenceNumber = (_rxSeq == nil ? vita.sequence : (_rxSeq! + 1) % 16)
    
    // is the received Sequence Number correct?
    if vita.sequence != expectedSequenceNumber {
      
      // NO, log the issue
      os_log("Missing IqStream packet(s), rcvdSeq: %d, != expectedSeq: %d", log: _log, type: .default, vita.sequence, expectedSequenceNumber)
      
      _rxSeq = nil
      rxLostPacketCount += 1
    } else {
      
      _rxSeq = expectedSequenceNumber
    }
  }
}

extension IqStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _available: Int {
    get { return _q.sync { __available } }
    set { _q.sync(flags: .barrier) { __available = newValue } } }
  
  internal var _capacity: Int {
    get { return _q.sync { __capacity } }
    set { _q.sync(flags: .barrier) { __capacity = newValue } } }
  
  internal var _daxIqChannel: DaxIqChannel {
    get { return _q.sync { __daxIqChannel } }
    set { _q.sync(flags: .barrier) { __daxIqChannel = newValue } } }
  
  internal var _inUse: Bool {
    get { return _q.sync { __inUse } }
    set { _q.sync(flags: .barrier) { __inUse = newValue } } }
  
  internal var _ip: String {
    get { return _q.sync { __ip } }
    set { _q.sync(flags: .barrier) { __ip = newValue } } }
  
  internal var _port: Int {
    get { return _q.sync { __port } }
    set { _q.sync(flags: .barrier) { __port = newValue } } }
  
  internal var _pan: PanadapterId {
    get { return _q.sync { __pan } }
    set { _q.sync(flags: .barrier) { __pan = newValue } } }
  
  internal var _rate: Int {
    get { return _q.sync { __rate } }
    set { _q.sync(flags: .barrier) { __rate = newValue } } }
  
  internal var _streaming: Bool {
    get { return _q.sync { __streaming } }
    set { _q.sync(flags: .barrier) { __streaming = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var available: Int {
    return _available }
  
  @objc dynamic public var capacity: Int {
    return _capacity }
  
  @objc dynamic public var daxIqChannel: DaxIqChannel {
    return _daxIqChannel }
  
  @objc dynamic public var inUse: Bool {
    return _inUse }
  
  @objc dynamic public var ip: String {
    return _ip }
  
  @objc dynamic public var port: Int {
    return _port  }
  
  @objc dynamic public var pan: PanadapterId {
    return _pan }
  
  @objc dynamic public var streaming: Bool {
    return _streaming  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var delegate: StreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // Mark: - Tokens
  
  /// Properties
  ///
  internal enum Token: String {
    case available
    case capacity
    case daxIqChannel                       = "daxiq"
    case inUse                              = "in_use"
    case ip
    case pan
    case port
    case rate
    case streaming
  }
}

