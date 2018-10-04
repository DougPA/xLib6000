//
//  Opus.swift
//  xLib6000
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation
import os

public typealias OpusId = UInt32

// --------------------------------------------------------------------------------
// MARK: - Opus Class implementation
//
//      creates an Opus instance to be used by a Client to support the
//      processing of a stream of Audio to/from the Radio. Opus
//      objects are added / removed by the incoming TCP messages. Opus
//      objects periodically receive/send Opus Audio in a UDP stream.
//
// --------------------------------------------------------------------------------

public final class Opus                     : NSObject, DynamicModelWithStream {

  public static let sampleRate              : Double = 24_000
  public static let frameCount              = 240
  public static let channelCount            = 2
  public static let isInterleaved           = true
  public static let application             = 2049
  public static let rxStreamId              : UInt32 = 0x4a000000
  public static let txStreamId              : UInt32 = 0x4b000000
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : OpusId                        // The Opus stream id

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "Opus")
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _clientHandle                 : UInt32 = 0                    //
  private var _ip                           = ""                            // IP Address of ???
  private var _port                         = 0                             // port number used by Opus
  private var _vita                         : Vita?                         // a Vita class
  private var _rxLostPacketCount            = 0                             // Rx lost packet count
  private var _rxSeq                        : Int?                          // Rx sequence number
  private var _txSeq                        = 0                             // Tx sequence number
  private var _txSampleCount                = 0                             // Tx sample count
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __rxEnabled                   = false                         // Opus for receive
  private var __txEnabled                   = false                         // Opus for transmit
  private var __rxStopped                   = false                         // Rx stream stopped
  //
  private weak var _delegate                : StreamHandler?                // Delegate for Opus Data Stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse an Opus status message
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray
  ///   - radio:              the current Radio class
  ///   - queue:              a parse Queue for the object
  ///   - inUse:              false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <streamId, > <"ip", ip> <"port", port> <"opus_rx_stream_stopped", 1|0>  <"rx_on", 1|0> <"tx_on", 1|0>
    
    // get the Opus Id (without the "0x" prefix)
    //        let opusId = String(keyValues[0].key.characters.dropFirst(2))
    if let streamId =  UInt32(String(keyValues[0].key.dropFirst(2)), radix: 16) {
      
      // does the Opus exist?
      if  radio.opusStreams[streamId] == nil {
        
        // NO, create a new Opus & add it to the OpusStreams collection
        radio.opusStreams[streamId] = Opus(id: streamId, queue: queue)
      }
      // pass the key values to Opus for parsing  (dropping the Id)
      radio.opusStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Opus
  ///
  /// - Parameters:
  ///   - id:                 an Opus Stream id
  ///   - queue:              Concurrent queue
  ///
  init(id: OpusId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Send Opus encoded TX audio to the Radio (hardware)
  ///
  /// - Parameters:
  ///   - buffer:             array of encoded audio samples
  /// - Returns:              success / failure
  ///
  public func sendTxAudio(buffer: [UInt8], samples: Int) {
    
    if _api.radio?.interlock.state == "TRANSMITTING" {
    
      // get an OpusTx Vita
      if _vita == nil { _vita = Vita(type: .opusTx, streamId: Opus.txStreamId) }
    
      // create new array for payload (interleaved L/R samples)
      _vita!.payloadData = buffer
      
      // set the length of the packet
      _vita!.payloadSize = samples                                              // 8-Bit encoded samples
      _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size    // payload size + header size
      
      // set the sequence number
      _vita!.sequence = _txSeq

      // encode the Vita class as data and send to radio
      if let data = Vita.encodeAsData(_vita!) {
        
        // send packet to radio
        _api.sendVitaData(data)
      }
      // increment the sequence number (mod 16)
      _txSeq = (_txSeq + 1) % 16
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ
  //
  
  ///  Parse Opus key/value pairs
  ///
  /// - Parameter properties: a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        
        // unknown Key, log it and ignore the Key
//        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .warning, function: #function, file: #file, line: #line)

        os_log("Unknown token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
      case .clientHandle:        
        willChangeValue(for: \.clientHandle)
        _clientHandle = UInt32(String(property.value.dropFirst(2)), radix: 16) ?? 0
        didChangeValue(for: \.clientHandle)

      case .ipAddress:
        willChangeValue(for: \.ip)
        _ip = property.value.trimmingCharacters(in: CharacterSet.whitespaces)
        didChangeValue(for: \.ip)

      case .port:
        willChangeValue(for: \.port)
        _port = property.value.iValue()
        didChangeValue(for: \.port)

      case .rxEnabled:
        willChangeValue(for: \.rxEnabled)
        _rxEnabled = property.value.bValue()
        didChangeValue(for: \.rxEnabled)

      case .txEnabled:
        willChangeValue(for: \.txEnabled)
        _txEnabled = property.value.bValue()
        didChangeValue(for: \.txEnabled)

      case .rxStopped:
        willChangeValue(for: \.rxStopped)
        _rxStopped = property.value.bValue()
        didChangeValue(for: \.rxStopped)
     }
    }
    // the Radio (hardware) has acknowledged this Opus
    if !_initialized && _ip != "" {
      
      // YES, the Radio (hardware) has acknowledged this Opus
      _initialized = true
      
      // notify all observers
      NC.post(.opusRxHasBeenAdded, object: self as Any?)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - VitaProcessor protocol methods
  
  //      called by Radio on the streamQ
  //
  //      The payload of the incoming Vita struct is converted to an OpusFrame and
  //      passed to the Opus Stream Handler where it is decoded
  
  /// Receive Opus encoded RX audio from the Radio (hardware)
  ///
  /// - Parameters:
  ///   - vita:               an Opus Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    // is this the first packet?
    if _rxSeq == nil { _rxSeq = vita.sequence ; _rxLostPacketCount = 0}
    
    // is the received Sequence Number correct?
    if vita.sequence != _rxSeq {
      
      // NO, log the issue
//      Log.sharedInstance.msg("Missing packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(_rxSeq!)", level: .warning, function: #function, file: #file, line: #line)

      os_log("Missing packet(s), rcvdSeq: %d,  != expectedSeq: %d", log: _log, type: .default, vita.sequence, _rxSeq!)
      
      if vita.sequence < _rxSeq! {
        
        // less than expected, packet is old, ignore it
        _rxSeq = nil
        _rxLostPacketCount += 1
        return
        
      } else {
        
        // greater than expected, one or more packets were lost, resync & process it
        _rxSeq = vita.sequence
        _rxLostPacketCount += 1
      }
    }
    // calculate the next Sequence Number
    _rxSeq = (_rxSeq! + 1) % 16
    
    // Pass the data frame to the Opus delegate
    delegate?.streamHandler( OpusFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize) )
  }
}

// ------------------------------------------------------------------------------
// MARK: - OpusFrame struct implementation
// ------------------------------------------------------------------------------

/// Struct containing Opus Stream data
///
public struct OpusFrame {
  
  public var samples: [UInt8]                     // array of samples
  public var numberOfSamples: Int                 // number of samples
  
  /*
   public var duration: Float                     // frame duration (ms)
   public var channels: Int                       // number of channels (1 or 2)
  */
  
  /// Initialize an OpusFrame
  ///
  /// - Parameters:
  ///   - payload:            pointer to the Vita packet payload
  ///   - numberOfSamples:    number of Samples in the payload
  ///
  public init(payload: UnsafeRawPointer, numberOfSamples: Int) {
    
    // allocate the samples array
    samples = [UInt8](repeating: 0, count: numberOfSamples)
    
    // save the count and copy the data
    self.numberOfSamples = numberOfSamples
    memcpy(&samples, payload, numberOfSamples)
    
    /*
     // MARK: This code unneeded at this time
     
     // Flex 6000 series uses:
     //     duration = 10 ms
     //     channels = 2 (stereo)
     
     // determine the frame duration
     let durationCode = (samples[0] & 0xF8)
     switch durationCode {
     case 0xC0:
     duration = 2.5
     case 0xC8:
     duration = 5.0
     case 0xD0:
     duration = 10.0
     case 0xD8:
     duration = 20.0
     default:
     duration = 0
     }
     // determine the number of channels (mono = 1, stereo = 2)
     channels = (samples[0] & 0x04) == 0x04 ? 2 : 1
    */
  }
}

// --------------------------------------------------------------------------------
// MARK: - Opus Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Opus tokens
// --------------------------------------------------------------------------------

extension Opus {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _rxEnabled: Bool {
    get { return _q.sync { __rxEnabled } }
    set { _q.sync(flags: .barrier) { __rxEnabled = newValue } } }
  
  internal var _txEnabled: Bool {
    get { return _q.sync { __txEnabled } }
    set { _q.sync(flags: .barrier) { __txEnabled = newValue } } }
  
  private var _rxStopped: Bool {
    get { return _q.sync { __rxStopped } }
    set { _q.sync(flags: .barrier) { __rxStopped = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var clientHandle: UInt32 {
    get { return _clientHandle }
    set { if _clientHandle != newValue { _clientHandle = newValue } } }
  
  @objc dynamic public var ip: String {
    get { return _ip }
    set { if _ip != newValue { _ip = newValue } } }

  @objc dynamic public var port: Int {
    get { return _port }
    set { if _port != newValue { _port = newValue } } }

  @objc dynamic public var rxStopped: Bool {
    get { return _rxStopped }
    set { if _rxStopped != newValue { _rxStopped = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var delegate: StreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Opus tokens
  
  internal enum Token : String {
    case clientHandle         = "client_handle"
    case ipAddress            = "ip"
    case port
    case rxEnabled            = "rx_on"
    case txEnabled            = "tx_on"
    case rxStopped            = "opus_rx_stream_stopped"
  }
}

