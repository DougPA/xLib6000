//
//  DaxIqStream.swift
//  xLib6000
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import Accelerate

/// DaxIqStream Class implementation
///
///      creates an DaxIqStream instance to be used by a Client to support the
///      processing of a stream of IQ data from the Radio to the client. DaxIqStream
///      objects are added / removed by the incoming TCP messages. DaxIqStream
///      objects periodically receive IQ data in a UDP stream. They are collected
///      in the daxIqStreams collection on the Radio object.
///
public final class DaxIqStream              : NSObject, DynamicModelWithStream {
 
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kCmd                           = "dax iq "                     // Command prefixes
  static let kStreamCreateCmd               = "stream create "
  static let kStreamRemoveCmd               = "stream remove "

  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var streamId          : StreamId = 0                  // Stream Id
  public private(set) var rxLostPacketCount = 0                             // Rx lost packet count

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _rxSeq                        : Int?                          // Rx sequence number

  // see FlexLib
  private var _kOneOverZeroDBfs             : Float = 1.0 / pow(2.0, 15.0)
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -------
  //
  private var __channel                     : DaxIqChannel = 0              // Channel in use (1 - 4)
  private var __clientHandle                : Handle = 0                    // Client for this DaxIqStream
  private var __pan                         : PanadapterId = 0              // Source Panadapter
  private var __rate                        = 0                             // Stream rate
  private var __isActive                    = false                         // Stream state
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
    // Format:  <streamId, > <"type", "dax_iq"> <"daxiq_channel", channel> <"pan", panStreamId> <"daxiq_rate", rate> <"client_handle", handle>
    // Format:  <streamId, > <"removed", >

    //get the StreamId (remove the "0x" prefix)
    if let streamId =  keyValues[0].key.streamId {
      
      // YES, does the Stream exist?
      if radio.daxIqStreams[streamId] == nil {
        
        // exit if it has been removed
        if inUse == false { return }
        
        // exit if this stream is not for this client
        if !DaxRxAudioStream.isStatusForThisClient( Array(keyValues.dropFirst(5)) ) { return }
        
        // create a new Stream & add it to the collection
        radio.daxIqStreams[streamId] = DaxIqStream(streamId: streamId, queue: queue)
      }
      // pass the remaining key values to parsing
      radio.daxIqStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
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
  public class func findBy(channel: DaxIqChannel) -> DaxIqStream? {

    // find the IQ Streams with the specified Channel (if any)
    let streams = Api.sharedInstance.radio!.daxIqStreams.values.filter { $0.channel == channel }
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
  init(streamId: StreamId, queue: DispatchQueue) {
    
    self.streamId = streamId
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
        _log.msg("Unknown IqStream token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .clientHandle:
        willChangeValue(for: \.clientHandle)
        _clientHandle = property.value.handle ?? 0
        didChangeValue(for: \.clientHandle)
        
      case .channel:
        willChangeValue(for: \.channel)
        _channel = property.value.iValue
        didChangeValue(for: \.channel)

      case .isActive:
        willChangeValue(for: \.isActive)
        _isActive = property.value.bValue
        didChangeValue(for: \.isActive)

      case .pan:
        willChangeValue(for: \.pan)
        _pan = property.value.streamId ?? 0
        didChangeValue(for: \.pan)

      case .rate:
        willChangeValue(for: \.rate)
        _rate = property.value.iValue
        didChangeValue(for: \.rate)
      }
    }
    // is the Stream initialized?
    if !_initialized && _clientHandle != 0 {
      
      // YES, the Radio (hardware) has acknowledged this Stream
      _initialized = true
      
      // notify all observers
      NC.post(.daxIqStreamHasBeenAdded, object: self as Any?)
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
      
      dataFrame.daxIqChannel = channel
      
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
      _log.msg( "Missing IqStream packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(expectedSequenceNumber)", level: .warning, function: #function, file: #file, line: #line)
      _rxSeq = nil
      rxLostPacketCount += 1
    } else {
      
      _rxSeq = expectedSequenceNumber
    }
  }
}

extension DaxIqStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _channel: DaxIqChannel {
    get { return _q.sync { __channel } }
    set { _q.sync(flags: .barrier) { __channel = newValue } } }
  
  internal var _clientHandle: Handle {
    get { return _q.sync { __clientHandle } }
    set { _q.sync(flags: .barrier) { __clientHandle = newValue } } }
  
  internal var _pan: PanadapterId {
    get { return _q.sync { __pan } }
    set { _q.sync(flags: .barrier) { __pan = newValue } } }
  
  internal var _rate: Int {
    get { return _q.sync { __rate } }
    set { _q.sync(flags: .barrier) { __rate = newValue } } }
  
  internal var _isActive: Bool {
    get { return _q.sync { __isActive } }
    set { _q.sync(flags: .barrier) { __isActive = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var channel: DaxIqChannel {
    return _channel }
  
  @objc dynamic public var clientHandle: Handle {
    return _clientHandle }
  
  @objc dynamic public var pan: PanadapterId {
    return _pan }
  
  @objc dynamic public var isActive: Bool {
    return _isActive  }
  
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
    case clientHandle                       = "client_handle"
    case channel                            = "daxiq_channel"
    case pan
    case rate                               = "daxiq_rate"
    case isActive                           = "active"
  }
}

