//
//  IqStream.swift
//  xLib6000
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import Accelerate

// --------------------------------------------------------------------------------
// MARK: - IqStreamHandler protocol
//
// --------------------------------------------------------------------------------

public protocol IqStreamHandler             : class {
  
  /// Method to process an IQ stream
  ///
  /// - Parameter frame:          an IqStreamFrame struct
  ///
  func iqStreamHandler(_ frame: IqStreamFrame)
}

// ------------------------------------------------------------------------------
// MARK: - IqStream Class implementation
//
//      creates a UDP stream of I / Q data, from a Panadapter in the Radio (hardware) to
//      to the Client, to be used by the client for various purposes (e.g. CW Skimmer,
//      digital modes, etc.)
//
// ------------------------------------------------------------------------------

public final class IqStream                 : NSObject, StatusParser, PropertiesParser {
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : DaxStreamId = 0               // Stream Id

  public private(set) var rxLostPacketCount = 0                             // Rx lost packet count

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
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
  private weak var _delegate                : IqStreamHandler?              // Delegate for IQ stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -------
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an IQ Stream
  ///
  /// - Parameters:
  ///   - id:                 the Stream Id
  ///   - radio:              the Radio instance
  ///   - queue:              Concurrent queue
  ///
  init(id: DaxStreamId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - StatusParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse a Stream status message
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
          if !radio.isAudioStreamStatusForThisClient(keyValues) { return }
          
          // create a new Stream & add it to the Streams collection
          radio.iqStreams[streamId] = IqStream(id: streamId, queue: queue)
        }
        // pass the remaining key values to the IqStream for parsing (dropping the Id)
        radio.iqStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
        
      } else {
        
        // NO, notify all observers
        NC.post(.iqStreamWillBeRemoved, object: radio.iqStreams[streamId] as Any?)
        
        // remove it
        radio.iqStreams[streamId] = nil
      }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse IQ Stream key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      guard let token = Token(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .available:
        willChangeValue(forKey: "available")
        _available = property.value.iValue()
        didChangeValue(forKey: "available")
        
      case .capacity:
        willChangeValue(forKey: "capacity")
        _capacity = property.value.iValue()
        didChangeValue(forKey: "capacity")
        
      case .daxIqChannel:
        willChangeValue(forKey: "daxIqChannel")
        _daxIqChannel = property.value.iValue()
        didChangeValue(forKey: "daxIqChannel")
        
      case .inUse:
        willChangeValue(forKey: "inUse")
        _inUse = property.value.bValue()
        didChangeValue(forKey: "inUse")
        
      case .ip:
        willChangeValue(forKey: "ip")
        _ip = property.value
        didChangeValue(forKey: "ip")
        
      case .pan:
        willChangeValue(forKey: "pan")
        _pan = UInt32(property.value.dropFirst(2), radix: 16) ?? 0
        didChangeValue(forKey: "pan")
        
      case .port:
        willChangeValue(forKey: "port")
        _port = property.value.iValue()
        didChangeValue(forKey: "port")
        
      case .rate:
        willChangeValue(forKey: "rate")
        _rate = property.value.iValue()
        didChangeValue(forKey: "rate")
        
      case .streaming:
        willChangeValue(forKey: "streaming")
        _streaming = property.value.bValue()
        didChangeValue(forKey: "streaming")
      }
    }
    // is the Stream initialized?
    if !_initialized && /*_inUse &&*/ _ip != "" {   // in_use is not send at the beginning
      
      // YES, the Radio (hardware) has acknowledged this Stream
      _initialized = true
      
      // notify all observers
      NC.post(.iqStreamHasBeenAdded, object: self as Any?)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - VitaHandler Protocol method
  
  //      called by Radio on the udpReceiveQ
  //
  //      The payload of the incoming Vita struct is converted to an IqStreamFrame and
  //      passed to the IQ Stream Handler
  
  /// Process the IqStream Vita struct
  ///
  /// - Parameters:
  ///   - vita:       a Vita struct
  ///
  func vitaHandler(_ vita: Vita) {
    
    if vita.classCode != .daxIq24 && vita.classCode != .daxIq48 && vita.classCode != .daxIq96 && vita.classCode != .daxIq192 {
      // not for us
      return
    }
    
    // if there is a delegate, process the Panadapter stream
    if let delegate = delegate {
      
      // initialize a data frame
      var dataFrame = IqStreamFrame(payload: vita.payload!, numberOfBytes: vita.payloadSize)
      
      dataFrame.daxIqChannel = self.daxIqChannel
      
      // get a pointer to the data in the payload
      guard let wordsPtr = vita.payload?.bindMemory(to: Float32.self, capacity: dataFrame.samples * 2) else {
        return
      }
      
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
      delegate.iqStreamHandler(dataFrame)
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
// MARK: - IqStreamFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the IQ Stream vitaHandler
//

/// Struct containing IQ Stream data
///
public struct IqStreamFrame {
  
  public var daxIqChannel                   = -1
  public private(set) var samples           = 0                             // number of samples (L/R) in this frame
  public var realSamples                    = [Float]()                     // Array of real (I) samples
  public var imagSamples                    = [Float]()                     // Array of imag (Q) samples
  
  /// Initialize an IqtreamFrame
  ///
  /// - Parameters:
  ///   - payload:        pointer to a Vita packet payload
  ///   - numberOfBytes:  number of bytes in the payload
  ///
  public init(payload: UnsafeRawPointer, numberOfBytes: Int) {
    
    // 4 byte each for left and right sample (4 * 2)
    self.samples = numberOfBytes / (4 * 2)
    
    // allocate the samples arrays
    self.realSamples = [Float](repeating: 0, count: samples)
    self.imagSamples = [Float](repeating: 0, count: samples)
  }
}

// --------------------------------------------------------------------------------
// MARK: - IqStream Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - IqStream tokens
// --------------------------------------------------------------------------------

extension IqStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
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
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
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
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var delegate: IqStreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // Mark: - IqStream tokens
  
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
