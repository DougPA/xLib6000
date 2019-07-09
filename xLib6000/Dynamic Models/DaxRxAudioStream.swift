//
//  DaxRxAudioStream.swift
//  xLib6000
//
//  Created by Douglas Adams on 2/24/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

public typealias DaxChannel = Int
public typealias DaxIqChannel = Int

/// DaxRxAudioStream Class implementation
///
///      creates a DaxRxAudioStream instance to be used by a Client to support the
///      processing of a stream of Audio from the Radio to the client. DaxRxAudioStream
///      objects are added / removed by the incoming TCP messages. DaxRxAudioStream
///      objects periodically receive Audio in a UDP stream. They are collected
///      in the daxRxAudioStreams collection on the Radio object.
///
public final class DaxRxAudioStream         : NSObject, DynamicModelWithStream {
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var streamId          : StreamId = 0                  // The Audio stream id

  public private(set) var rxLostPacketCount = 0                             // Rx lost packet count

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue!                // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _rxSeq                        : Int?                          // Rx sequence number
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __clientHandle                : Handle = 0                    // Client for this DaxRxAudioStream
  private var __daxChannel                  = 0                             // Channel in use (1 - 8)
  private var __daxClients                  = 0                             // Number of clients
  private var __rxGain                      = 50                            // rx gain of stream
  private var __slice                       : xLib6000.Slice?               // Source Slice
  //
  private weak var _delegate                : StreamHandler?                // Delegate for Audio stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods

  /// Parse an AudioStream status message
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
    // Format:  <streamId, > <"type", "dax_rx"> <"dax_channel", channel> <"slice", sliceNumber> <"dax_clients", number> <"client_handle", handle>
    // Format:  <streamId, > <"removed", >

    //get the StreamId
    if let streamId =  keyValues[0].key.streamId {
      
      // does the Stream exist?
      if radio.daxRxAudioStreams[streamId] == nil {
        
        // exit if it has been removed
        if inUse == false { return }
        
        // exit if this stream is not for this client
        if !DaxRxAudioStream.isStatusForThisClient( Array(keyValues.dropFirst(5)) ) { return }

        // create a new Stream & add it to the collection
        radio.daxRxAudioStreams[streamId] = DaxRxAudioStream(streamId: streamId, queue: queue)
      }
      // pass the remaining key values to parsing
      radio.daxRxAudioStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(2)) )
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  /// Check if an Stream belongs to us
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray of the status message
  ///
  /// - Returns:              result of the check
  ///
  public class func isStatusForThisClient(_ properties: KeyValuesArray) -> Bool {
    
    // allow a Tester app to see all Streams
    guard Api.sharedInstance.testerModeEnabled == false else { return true }
    
    var handle : Handle? = nil
    
    // search thru each key/value pair, <key=value>
    for property in properties {
      
      switch property.key.lowercased() {
        
      case "client_handle":       handle = property.value.handle
      default:                    break
      }
    }
    return handle != nil && handle == Api.sharedInstance.connectionHandle
  }
  /// Find an AudioStream by DAX Channel
  ///
  /// - Parameter channel:    Dax channel number
  /// - Returns:              a DaxRxAudioStream (if any)
  ///
  public class func find(with channel: DaxChannel) -> DaxRxAudioStream? {
    
    // find the DaxRxAudioStream with the specified Channel (if any)
    let streams = Api.sharedInstance.radio!.daxRxAudioStreams.values.filter { $0.daxChannel == channel }
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
  init(streamId: StreamId, queue: DispatchQueue) {
    
    self.streamId = streamId
    _q = queue
    
    super.init()
  }

  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods
  
  /// Parse Audio Stream key/value pairs
  ///
  ///   PropertiesParser Protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown keys
      guard let token = Token(rawValue: property.key) else {
        // log it and ignore the Key
        _log.msg("Unknown DaxRxAudioStream token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .clientHandle:
        willChangeValue(for: \.clientHandle)
        _clientHandle = property.value.handle ?? 0
        didChangeValue(for: \.clientHandle)
        
      case .daxChannel:
        willChangeValue(for: \.daxChannel)
        _daxChannel = property.value.iValue
        didChangeValue(for: \.daxChannel)

      case .daxClients:
        willChangeValue(for: \.daxClients)
        _daxClients = property.value.iValue
        didChangeValue(for: \.daxClients)

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
    if !_initialized && _clientHandle != 0 {
      
      // YES, the Radio (hardware) has acknowledged this Audio Stream
      _initialized = true
      
      // notify all observers
      NC.post(.daxRxAudioStreamHasBeenAdded, object: self as Any?)
    }
  }
  /// Process the AudioStream Vita struct
  ///
  ///   VitaProcessor Protocol method, executes on the streamQ
  ///      The payload of the incoming Vita struct is converted to an AudioStreamFrame and
  ///      passed to the Audio Stream Handler, called by Radio
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
      _log.msg( "Missing AudioStream packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(expectedSequenceNumber)", level: .warning, function: #function, file: #file, line: #line)

      _rxSeq = nil
      rxLostPacketCount += 1
    } else {
      
      _rxSeq = expectedSequenceNumber
    }
  }
}

extension DaxRxAudioStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _clientHandle: Handle {
    get { return _q.sync { __clientHandle } }
    set { _q.sync(flags: .barrier) { __clientHandle = newValue } } }

  internal var _daxChannel: Int {
    get { return _q.sync { __daxChannel } }
    set { _q.sync(flags: .barrier) { __daxChannel = newValue } } }
  
  internal var _daxClients: Int {
    get { return _q.sync { __daxClients } }
    set { _q.sync(flags: .barrier) { __daxClients = newValue } } }
  
  internal var _rxGain: Int {
    get { return _q.sync { __rxGain } }
    set { _q.sync(flags: .barrier) { __rxGain = newValue } } }
  
  internal var _slice: xLib6000.Slice? {
    get { return _q.sync { __slice } }
    set { _q.sync(flags: .barrier) { __slice = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var clientHandle: Handle {
    get { return _clientHandle  }
    set { if _clientHandle != newValue { _clientHandle = newValue } } }
  
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
  
  @objc dynamic public var slice: xLib6000.Slice? {
    get { return _slice }
    set { if _slice != newValue { _slice = newValue } } }
  
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
    case clientHandle                       = "client_handle"
    case daxChannel                         = "dax_channel"
    case daxClients                         = "dax_clients"
    case slice
  }
}


