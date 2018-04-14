//
//  Opus.swift
//  xLib6000
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

public typealias OpusId = UInt32

// --------------------------------------------------------------------------------
// MARK: - OpusStreamHandler protocol
//
// --------------------------------------------------------------------------------

public protocol OpusStreamHandler           : class {
  
  /// Method to process an Opus stream (Opus audio from the Radio hardware)
  ///
  /// - Parameter frame:          an OpusFrame struct
  ///
  func streamHandler(_ frame: OpusFrame) -> Void
}

// --------------------------------------------------------------------------------
// MARK: - Opus Class implementation
//
//      creates an Opus instance to be used by a Client to support the
//      processing of a stream of Audio to/from the Radio from/to the client. Opus
//      objects are added / removed by the incoming TCP messages. Opus
//      objects periodically receive/send Opus Audio in a UDP stream.
//
// --------------------------------------------------------------------------------

public final class Opus                     : NSObject, StatusParser, PropertiesParser, VitaProcessor {
    
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : OpusId                        // The Opus stream id

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _ip                           = ""                            // IP Address of ???
  private var _port                         = 0                             // port number used by Opus
  
  private var rxSeq                         : Int?                          // Rx sequence number
  private var rxByteCount                   = 0                             // Rx byte count
  private var rxPacketCount                 = 0                             // Rx packet count
  private var rxBytesPerSec                 = 0                             // Rx rate
  private var rxLostPacketCount             = 0                             // Rx lost packet count
  
  private var txSeq                         = 0                             // Tx sequence number
  private var txByteCount                   = 0                             // Tx byte count
  private var _txPacketSize                 = 240                           // Tx packet size (bytes)
  private var txBytesPerSec                 = 0                             // Tx rate
  
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __remoteRxOn                  = false                         // Opus for receive
  private var __remoteTxOn                  = false                         // Opus for transmit
  private var __rxStreamStopped             = false                         // Rx stream stopped
  //
  private weak var _delegate                : OpusStreamHandler? {    // Delegate for Opus Data Stream
    didSet { if _delegate == nil { _initialized = false ; rxSeq = nil } } }
  //                                                                                                  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ----------------------------------------------------------------------------
  // MARK: - StatusParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse an Opus status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <streamId, > <"ip", ip> <"port", port> <"opus_rx_stream_stopped", 1|0>  <"rx_on", 1|0> <"tx_on", 1|0>
    
    // get the Opus Id (without the "0x" prefix)
    //        let opusId = String(keyValues[0].key.characters.dropFirst(2))
    if let streamId =  UInt32(String(keyValues[1].key.dropFirst(2)), radix: 16) {
      
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
  ///   - radio:              the parent Radio class
  ///   - queue:              Concurrent queue
  ///
  init(id: OpusId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public methods
  
  private var _vita: Vita?
  /// Send Opus encoded TX audio to the Radio (hardware)
  ///
  /// - Parameters:
  ///   - buffer:     array of encoded audio samples
  ///   - samples:    number of samples to be sent
  /// - Returns:      success / failure
  ///
  public func sendOpusTxAudio(buffer: [UInt8], samples: Int) {
    
    if _vita == nil {
      // get a new Vita struct (w/defaults & IfDataWithStream, daxAudio, StreamId, tsi.other)
      _vita = Vita(packetType: .ifDataWithStream, classCode: .daxAudio, streamId: id, tsi: .other)
    }
    // create new array for payload (interleaved L/R samples)
    _vita!.payloadData = [UInt8](repeating: 0, count: _txPacketSize)
    
    // set the length of the packet
    _vita!.payloadSize = _txPacketSize                                      // 8-Bit encoded samples
    _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size     // payload size + header size
    
    // set the sequence number
    _vita!.sequence = txSeq
    
    // encode the Vita class as data and send to radio
    if let data = Vita.encodeAsData(_vita!) {
      
      // send packet to radio
      Api.sharedInstance.sendVitaData(data)
    }
    // increment the sequence number (mod 16)
    txSeq = (txSeq + 1) % 16
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ
  //
  
  ///  Parse Opus key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        
        // unknown Key, log it and ignore the Key
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
      case .ipAddress:
        willChangeValue(forKey: "ip")
        _ip = property.value.trimmingCharacters(in: CharacterSet.whitespaces)
        didChangeValue(forKey: "ip")
        
      case .port:
        willChangeValue(forKey: "port")
        _port = property.value.iValue()
        didChangeValue(forKey: "port")
        
      case .remoteRxOn:
        willChangeValue(forKey: "remoteRxOn")
        _remoteRxOn = property.value.bValue()
        didChangeValue(forKey: "remoteRxOn")
        
      case .remoteTxOn:
        willChangeValue(forKey: "remoteTxOn")
        _remoteTxOn = property.value.bValue()
        didChangeValue(forKey: "remoteTxOn")
        
      case .rxStreamStopped:
        willChangeValue(forKey: "rxStreamStopped")
        _rxStreamStopped = property.value.bValue()
        didChangeValue(forKey: "rxStreamStopped")
      }
    }
    // the Radio (hardware) has acknowledged this Opus
    if !_initialized && _ip != "" {
      
      // YES, the Radio (hardware) has acknowledged this Opus
      _initialized = true
      
      // notify all observers
      NC.post(.opusHasBeenAdded, object: self as Any?)
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
  ///   - vita:       an Opus Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    // is this the first packet?
    if rxSeq == nil { rxSeq = vita.sequence }
    
    // is the received Sequence Number correct?
    if vita.sequence != rxSeq {
      
      // NO, log the issue
      Log.sharedInstance.msg("Missing packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(rxSeq!)", level: .warning, function: #function, file: #file, line: #line)
      
      if vita.sequence < rxSeq! {
        
        // less than expected, packet is old, ignore it
        rxSeq = nil
        rxLostPacketCount += 1
        return
        
      } else {
        
        // greater than expected, one or more packets were lost, resync & process it
        rxSeq = vita.sequence
        rxLostPacketCount += 1
      }
    }
    // calculate the next Sequence Number
    rxSeq = (rxSeq! + 1) % 16
    
    // Pass the data frame to the Opus delegate
    delegate?.streamHandler( OpusFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize) )
  }
}

// ------------------------------------------------------------------------------
// MARK: - OpusFrame struct implementation
// ------------------------------------------------------------------------------
//
//  Populated by the Opus vitaHandler
//

/// Struct containing Opus Stream data
///
public struct OpusFrame {
  
  public var samples: [UInt8]                     // array of samples
  public var numberOfSamples: Int                 // number of samples
  
  /*
   public var duration: Float                      // frame duration (ms)
   public var channels: Int                        // number of channels (1 or 2)
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
     
     // determine the frame duration
     let durationCode = (samples[0] & 0xF8)
     switch durationCode {
     case 0xC0:
     duration = 2.5
     case 0xC8:
     duration = 5.0
     case 0xD0:
     duration = 10.0                                 // Flex uses 10 ms
     case 0xD8:
     duration = 20.0
     default:
     duration = 0
     }
     // determine the number of channels (mono = 1, stereo = 2)
     channels = (samples[0] & 0x04) == 0x04 ? 2 : 1      // Flex uses stereo
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
  internal var _remoteRxOn: Bool {
    get { return _q.sync { __remoteRxOn } }
    set { _q.sync(flags: .barrier) { __remoteRxOn = newValue } } }
  
  internal var _remoteTxOn: Bool {
    get { return _q.sync { __remoteTxOn } }
    set { _q.sync(flags: .barrier) { __remoteTxOn = newValue } } }
  
  private var _rxStreamStopped: Bool {
    get { return _q.sync { __rxStreamStopped } }
    set { _q.sync(flags: .barrier) { __rxStreamStopped = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var rxStreamStopped: Bool {
    get { return _rxStreamStopped }
    set { if _rxStreamStopped != newValue { _rxStreamStopped = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var delegate: OpusStreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Opus tokens
  
  internal enum Token : String {
    case ipAddress          = "ip"
    case port
    case remoteRxOn         = "rx_on"
    case remoteTxOn         = "tx_on"
    case rxStreamStopped    = "opus_rx_stream_stopped"
  }
}

