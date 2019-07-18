//
//  RemoteRxAudioStream.swift
//  xLib6000
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

public typealias RemoteRxStreamId = StreamId

/// RemoteRxAudioStream Class implementation
///
///      creates an RemoteRxAudioStream instance to be used by a Client to support the
///      processing of a stream of Audio from the Radio. RemoteRxAudioStream objects
///      are added / removed by the incoming TCP messages. RemoteRxAudioStream objects
///      periodically receive Audio in a UDP stream. They are collected in the
///      RemoteRxAudioStreams collection on the Radio object.
///
public final class RemoteRxAudioStream      : NSObject, DynamicModelWithStream {
  
  // ------------------------------------------------------------------------------
  // MARK: - Static properties
  
  public static let sampleRate              : Double = 24_000
  public static let frameCount              = 240
  public static let channelCount            = 2
  public static let elementSize             = MemoryLayout<Float>.size
  public static let isInterleaved           = true
  public static let application             = 2049
  
  public static let kOpus                   = "opus"
  public static let kUncompressed           = "none"

  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var isStreaming                    = false
  public private(set) var streamId          : RemoteRxStreamId              // The RxRemoteAudioStream StreamId

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _vita                         : Vita?                         // a Vita class
  private var _rxPacketCount                = 0                             // Rx total packet count
  private var _rxLostPacketCount            = 0                             // Rx lost packet count
  private var _expectedFrame                : Int?                          // Rx sequence number
  private var _txSeq                        = 0                             // Tx sequence number
  private var _txSampleCount                = 0                             // Tx sample count
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __clientHandle                : Handle = 0
  private var __compression                 = RemoteRxAudioStream.kUncompressed
  private var __ip                          = ""
  //
  private weak var _delegate                : StreamHandler?                // Delegate for Opus Data Stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods
  
  /// Parse an RemoteRxAudioStream status message
  ///
  ///   StatusParser Protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray
  ///   - radio:              the current Radio class
  ///   - queue:              a parse Queue for the object
  ///   - inUse:              false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <streamId, > <"type", "remote_audio_rx"> <"compression", "none"|"opus"> <"client_handle", handle> <"ip", ip>
    
    // get the Stream Id
    if let streamId = keyValues[0].key.streamId {
      
      // does the Stream exist?
      if  radio.remoteRxAudioStreams[streamId] == nil {
        
        // exit if this stream is not for this client
        if isForThisClient(handle: keyValues[3].value ) == false { return }
        
        // create a new Stream & add it to the collection
        radio.remoteRxAudioStreams[streamId] = RemoteRxAudioStream(streamId: streamId, queue: queue)
        
        Swift.print("streamId = \(radio.remoteRxAudioStreams[streamId]!.streamId.hex)")
      }
      // pass the remaining key values to parsing
      radio.remoteRxAudioStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(2)) )
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize RemoteRxAudioStream
  ///
  /// - Parameters:
  ///   - id:                 an Opus Stream id
  ///   - queue:              Concurrent queue
  ///
  init(streamId: RemoteRxStreamId, queue: DispatchQueue) {
    
    self.streamId = streamId
    _q = queue
    
    super.init()
    
    isStreaming = false
  }
 
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods
  
  ///  Parse RemoteRxAudioStream key/value pairs
  ///
  ///   PropertiesParser Protocol method, executes on the parseQ
  ///
  /// - Parameter properties: a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        // log it and ignore the Key
        _log.msg("Unknown RemoteRxAudioStream token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
      case .clientHandle:        
        willChangeValue(for: \.clientHandle)
        _clientHandle = property.value.handle ?? 0
        didChangeValue(for: \.clientHandle)

      case .compression:
        willChangeValue(for: \.compression)
        _compression = property.value.lowercased()
        didChangeValue(for: \.compression)
      
      case .ip:
        willChangeValue(for: \.ip)
        _ip = property.value
        didChangeValue(for: \.ip)
     }
    }
    // the Radio (hardware) has acknowledged this RxRemoteAudioStream
    if _initialized == false && _clientHandle != 0 {
      
      // YES, the Radio (hardware) has acknowledged this RxRemoteAudioStream
      _initialized = true
      
      // notify all observers
      NC.post(.remoteRxAudioStreamHasBeenAdded, object: self as Any?)
    }
  }
  /// Receive RxRemoteAudioStream audio
  ///
  ///   VitaProcessor protocol method, called by Radio ,executes on the streamQ
  ///       The payload of the incoming Vita struct is converted to an OpusFrame and
  ///       passed to the delegate's Stream Handler
  ///
  /// - Parameters:
  ///   - vita:               an Opus Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    // is this the first packet?
    if _expectedFrame == nil {
      _expectedFrame = vita.sequence
      _rxPacketCount = 1
      _rxLostPacketCount = 0
    } else {
      _rxPacketCount += 1
    }

    switch (_expectedFrame!, vita.sequence) {

//    case (let expected, let received) where received < expected:
//      // from a previous group, ignore it
//      _log.msg("Delayed frame(s): expected \(expected), received \(received)", level: .warning, function: #function, file: #file, line: #line)
//      return
      
    case (let expected, let received) where received > expected:
      _rxLostPacketCount += 1
      
      // from a later group, jump forward
      let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
      _log.msg("Missing frame(s): expected \(expected), received \(received), loss = \(lossPercent) %", level: .warning, function: #function, file: #file, line: #line)

      // Pass an error frame (count == 0) to the Opus delegate
      delegate?.streamHandler( OpusFrame(payload: vita.payloadData, sampleCount: 0) )

      _expectedFrame = received
      fallthrough

    default:
      // received == expected
      // calculate the next Sequence Number
      _expectedFrame = (_expectedFrame! + 1) % 16

      // Pass the data frame to the Opus delegate
      delegate?.streamHandler( OpusFrame(payload: vita.payloadData, sampleCount: vita.payloadSize) )
    }
  }
}

extension RemoteRxAudioStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _clientHandle: Handle {
    get { return _q.sync { __clientHandle } }
    set { _q.sync(flags: .barrier) { __clientHandle = newValue } } }
  
  internal var _compression: String {
    get { return _q.sync { __compression } }
    set { _q.sync(flags: .barrier) { __compression = newValue } } }
    
  internal var _ip: String {
    get { return _q.sync { __ip } }
    set { _q.sync(flags: .barrier) { __ip = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - NON Public properties (KVO compliant)
  
  public var delegate: StreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }

  @objc dynamic public var clientHandle: Handle {
    get { return _clientHandle  }
    set { if _clientHandle != newValue { _clientHandle = newValue} } }
  
  @objc dynamic public var compression: String {
    get { return _compression  }
    set { if _compression != newValue { _compression = newValue} } }
  
  @objc dynamic public var ip: String {
    get { return _ip  }
    set { if _ip != newValue { _ip = newValue} } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum Token : String {
    case clientHandle         = "client_handle"
    case compression
    case ip
  }
}


