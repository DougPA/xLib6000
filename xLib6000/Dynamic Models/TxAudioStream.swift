//
//  TxAudioStream.swift
//  xLib6000
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa

// ------------------------------------------------------------------------------
// MARK: - TxAudioStream Class implementation
//
//      creates a TxAudioStream instance to be used by a Client to support the
//      processing of a stream of Audio from the client to the Radio. TxAudioStream
//      objects are added / removed by the incoming TCP messages. TxAudioStream
//      objects periodically send Tx Audio in a UDP stream.
//
// ------------------------------------------------------------------------------

public final class TxAudioStream            : NSObject, StatusParser, PropertiesParser {
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : DaxStreamId = 0               // Stream Id

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _txSeq                        = 0                             // Tx sequence number (modulo 16)
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //                                                                                                  
  private var __inUse                       = false                         // true = in use
  private var __ip                          = ""                            // Ip Address
  private var __port                        = 0                             // Port number
  private var __transmit                    = false                         // dax transmitting
  private var __txGain                      = 50                            // tx gain of stream
  private var __txGainScalar                : Float = 1.0                   // scalar gain value for multiplying
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a TxAudioStream status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <streamId, > <"dax_tx", channel> <"in_use", 1|0> <"ip", ip> <"port", port>
    
    //get the AudioStreamId (remove the "0x" prefix)
    if let streamId =  UInt32(String(keyValues[0].key.dropFirst(2)), radix: 16) {
      
      // is the TX Audio Stream in use?
      if inUse {
        
        // YES, does the AudioStream exist?
        if radio.txAudioStreams[streamId] == nil {
          
          // NO, is this stream for this client?
          if !AudioStream.isStatusForThisClient(keyValues) { return }
          
          // create a new AudioStream & add it to the AudioStreams collection
          radio.txAudioStreams[streamId] = TxAudioStream(id: streamId, queue: queue)
        }
        // pass the remaining key values to the AudioStream for parsing (dropping the Id)
        radio.txAudioStreams[streamId]!.parseProperties( Array(keyValues.dropFirst(1)) )
        
      } else {
        
        // does the stream exist?
        if let stream = radio.txAudioStreams[streamId] {
          
          // notify all observers
          NC.post(.txAudioStreamWillBeRemoved, object: stream as Any?)
          
          // remove the stream object
          radio.txAudioStreams[streamId] = nil
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an TX Audio Stream
  ///
  /// - Parameters:
  ///   - id:                 Dax stream Id
  ///   - radio:              the Radio instance
  ///   - queue:              Concurrent queue
  ///
  init(id: DaxStreamId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public methods for sending tx audio to the Radio (hardware)
  
  private var _vita: Vita?
  public func sendTXAudio(left: [Float], right: [Float], samples: Int) -> Bool {
    
    // skip this if we are not the DAX TX Client
    if !_transmit { return false }
    
    if _vita == nil {
      // get a new Vita struct (w/defaults & IfDataWithStream, daxAudio, StreamId, tsi.other)
      _vita = Vita(packetType: .ifDataWithStream, classCode: .daxAudio, streamId: id, tsi: .other)
    }
    
    let kMaxSamplesToSend = 128     // maximum packet samples (per channel)
    let kNumberOfChannels = 2       // 2 channels
    
    // create new array for payload (interleaved L/R samples)
    let payloadData = [UInt8](repeating: 0, count: kMaxSamplesToSend * kNumberOfChannels * MemoryLayout<Float>.size)
    
    // get a raw pointer to the start of the payload
    let payloadPtr = UnsafeMutableRawPointer(mutating: payloadData)
    
    // get a pointer to 32-bit chunks in the payload
    let wordsPtr = payloadPtr.bindMemory(to: UInt32.self, capacity: kMaxSamplesToSend * kNumberOfChannels)
    
    // get a pointer to Float chunks in the payload
    let floatPtr = payloadPtr.bindMemory(to: Float.self, capacity: kMaxSamplesToSend * kNumberOfChannels)
    
    var samplesSent = 0
    while samplesSent < samples {
      
      // how many samples this iteration? (kMaxSamplesToSend or remainder if < kMaxSamplesToSend)
      let numSamplesToSend = min(kMaxSamplesToSend, samples - samplesSent)
      let numFloatsToSend = numSamplesToSend * kNumberOfChannels
      
      // interleave the payload & scale with tx gain
      for i in 0..<numSamplesToSend {                                         // TODO: use Accelerate
        floatPtr.advanced(by: 2 * i).pointee = left[i + samplesSent] * _txGainScalar
        floatPtr.advanced(by: (2 * i) + 1).pointee = left[i + samplesSent] * _txGainScalar

//        payload[(2 * i)] = left[i + samplesSent] * _txGainScalar
//        payload[(2 * i) + 1] = right[i + samplesSent] * _txGainScalar
      }
      
      // swap endianess of the samples
      for i in 0..<numFloatsToSend {
        wordsPtr.advanced(by: i).pointee = CFSwapInt32HostToBig(wordsPtr.advanced(by: i).pointee)
      }
      
      _vita!.payloadData = payloadData

      // set the length of the packet
      _vita!.payloadSize = numFloatsToSend * MemoryLayout<UInt32>.size        // 32-Bit L/R samples
      _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size     // payload size + header size
      
      // set the sequence number
      _vita!.sequence = _txSeq
      
      // encode the Vita class as data and send to radio
      if let data = Vita.encodeAsData(_vita!) {
        
        // send packet to radio
        Api.sharedInstance.sendVitaData(data)
      }
      // increment the sequence number (mod 16)
      _txSeq = (_txSeq + 1) % 16
      
      // adjust the samples sent
      samplesSent += numSamplesToSend
    }
    return true
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse TX Audio Stream key/value pairs
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
        
      case .daxTx:
        update(&_transmit, value: property.value.bValue(), key: "transmit")

      case .inUse:
        update(&_inUse, value: property.value.bValue(), key: "inUse")

      case .ip:
        update(&_ip, value: property.value, key: "ip")

      case .port:
        update(&_port, value: property.value.iValue(), key: "port")
      }
    }
    // is the AudioStream acknowledged by the radio?
    if !_initialized && _inUse && _ip != "" {
      
      // YES, the Radio (hardware) has acknowledged this Audio Stream
      _initialized = true
      
      // notify all observers
      NC.post(.txAudioStreamHasBeenAdded, object: self as Any?)
    }
  }
  /// Update a property & signal KVO
  ///
  /// - Parameters:
  ///   - property:           the property (mutable)
  ///   - value:              the new value
  ///   - key:                the KVO key
  ///
  private func update<T: Equatable>(_ property: inout T, value: T, key: String) {
    
    // update the property & signal KVO (if needed)
//    if property != value {
      willChangeValue(forKey: key)
      property = value
      didChangeValue(forKey: key)
//    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - MicAudioStream Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - TxAudioStream tokens
// --------------------------------------------------------------------------------

extension TxAudioStream {
  
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
  
  internal var _transmit: Bool {
    get { return _q.sync { __transmit } }
    set { _q.sync(flags: .barrier) { __transmit = newValue } } }
  
  internal var _txGain: Int {
    get { return _q.sync { __txGain } }
    set { _q.sync(flags: .barrier) { __txGain = newValue } } }
  
  internal var _txGainScalar: Float {
    get { return _q.sync { __txGainScalar } }
    set { _q.sync(flags: .barrier) { __txGainScalar = newValue } } }
  
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
  
  
  @objc dynamic public var txGain: Int {
    get { return _txGain  }
    set {
      if _txGain != newValue {
        let value = newValue.bound(0, 100)
        if _txGain != value {
          _txGain = value
          if _txGain == 0 {
            _txGainScalar = 0.0
            return
          }
          let db_min:Float = -10.0;
          let db_max:Float = +10.0;
          let db:Float = db_min + (Float(_txGain) / 100.0) * (db_max - db_min);
          _txGainScalar = pow(10.0, db / 20.0);
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - TxAudioStream tokens
  
  internal enum Token: String {
    case daxTx      = "dax_tx"
    case inUse      = "in_use"
    case ip
    case port
  }
}

