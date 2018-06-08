//
//  Radio.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Radio Class implementation
//
//      as the object analog to the Radio (hardware), manages the use of all of
//      the other model objects
//
// --------------------------------------------------------------------------------

public final class Radio                    : NSObject, StaticModel, ApiDelegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (Read Only)
  
  public private(set) var uptime            = 0
  @objc dynamic public var radioVersion     : String { return _api.activeRadio?.firmwareVersion ?? "" }
  
  // Static models
  @objc dynamic public private(set) var atu         : Atu!                  // Atu model
  @objc dynamic public private(set) var cwx         : Cwx!                  // Cwx model
  @objc dynamic public private(set) var gps         : Gps!                  // Gps model
  @objc dynamic public private(set) var interlock   : Interlock!            // Interlock model
  @objc dynamic public private(set) var profile     : Profile!              // Profile model
  @objc dynamic public private(set) var transmit    : Transmit!             // Transmit model
  @objc dynamic public private(set) var wan         : Wan!                  // Wan model
  @objc dynamic public private(set) var waveform    : Waveform!             // Waveform model
  
  @objc dynamic public private(set) var antennaList = [AntennaPort]()       // Array of available Antenna ports
  @objc dynamic public private(set) var micList     = [MicrophonePort]()    // Array of Microphone ports
  @objc dynamic public private(set) var rfGainList  = [RfGainValue]()       // Array of RfGain parameters
  @objc dynamic public private(set) var sliceList   = [SliceId]()           // Array of available Slice id's
  
  public private(set) var sliceErrors       = [String]()                    // frequency error of a Slice (milliHz)

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _api                          = Api.sharedInstance            // reference to the API singleton
  private var _radioInitialized = false
  private var _hardwareVersion              : String?                       // ???

  // GCD Queue
  private let _objectQ                      : DispatchQueue
  private let _streamQ                      = DispatchQueue(label: Api.kId + ".streamQ", qos: .userInteractive)
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  // object collections
  private var _amplifiers                   = [AmplifierId: Amplifier]()    // Dictionary of Amplifiers
  private var _audioStreams                 = [DaxStreamId: AudioStream]()  // Dictionary of Audio streams
  private var _equalizers                   = [Equalizer.EqType: Equalizer]() // Dictionary of Equalizers
  private var _iqStreams                    = [DaxStreamId: IqStream]()     // Dictionary of Dax Iq streams
  private var _memories                     = [MemoryId: Memory]()          // Dictionary of Memories
  private var _meters                       = [MeterId: Meter]()            // Dictionary of Meters
  private var _micAudioStreams              = [DaxStreamId: MicAudioStream]() // Dictionary of MicAudio streams
  private var _opusStreams                  = [OpusId: Opus]()              // Dictionary of Opus Streams
  private var _panadapters                  = [PanadapterId: Panadapter]()  // Dictionary of Panadapters
  private var _replyHandlers                = [SequenceId: ReplyTuple]()    // Dictionary of pending replies
  private var _slices                       = [SliceId: Slice]()            // Dictionary of Slices
  private var _tnfs                         = [TnfId: Tnf]()                // Dictionary of Tnfs
  private var _txAudioStreams               = [DaxStreamId: TxAudioStream]()// Dictionary of Tx Audio streams
  private var _usbCables                    = [UsbCableId: UsbCable]()      // Dictionary of UsbCables
  private var _waterfalls                   = [WaterfallId: Waterfall]()    // Dictionary of Waterfalls
  private var _xvtrs                        = [XvtrId: Xvtr]()              // Dictionary of Xvtrs
    
  // individual values
  // A
  private var __apfEnabled                  = false                         // auto-peaking filter enable
  private var __apfGain                     = 0                             // auto-peaking gain (0 - 100)
  private var __apfQFactor                  = 0                             // auto-peaking filter Q factor (0 - 33)
  private var __availablePanadapters        = 0                             // (read only)
  private var __availableSlices             = 0                             // (read only)
  // B
  private var __backlight                   = 0                             //
  private var __bandPersistenceEnabled      = false                         //
  private var __binauralRxEnabled           = false                         // Binaural enable
  // C
  private var __calFreq                     = 0                             // Calibration frequency
  private var __callsign                    = ""                            // Callsign
  private var __chassisSerial               = ""                            // Radio serial number (read only)
  private var __clientIp                    = ""                            // Ip address returned by "client ip" command
  // D
  private var __daxIqAvailable              = 0                             //
  private var __daxIqCapacity               = 0                             //
  // E
  private var __enforcePrivateIpEnabled     = false                         //
  // F
  private var __filterCwAutoLevel           = 0                             //
  private var __filterCwLevel               = 0                             //
  private var __filterDigitalAutoLevel      = 0                             //
  private var __filterDigitalLevel          = 0                             //
  private var __filterVoiceAutoLevel        = 0                             //
  private var __filterVoiceLevel            = 0                             //
  private var __fpgaMbVersion               = ""                            // FPGA version (read only)
  private var __freqErrorPpb                = 0                             // Calibration error (Hz)
  private var __fullDuplexEnabled           = false                         // Full duplex enable
  // G
  private var __gateway                     = ""                            // (read only)
  // H
  private var __headphoneGain               = 0                             // Headset gain (1-100)
  private var __headphoneMute               = false                         // Headset muted
  // I
  private var __ipAddress                   = ""                            // IP Address (dotted decimal) (read only)
  // L
  private var __lineoutGain                 = 0                             // Speaker gain (1-100)
  private var __lineoutMute                 = false                         // Speaker muted
  private var __location                    = ""                            // (read only)
  private var __locked                      = false                         //
  // M
  private var __macAddress                  = ""                            // Radio Mac Address (read only)
  // N
  private var __netmask                     = ""                            //
  private var __nickname                    = ""                            // User assigned name
  private var __numberOfScus                = 0                             // NUmber of SCU's (read only)
  private var __numberOfSlices              = 0                             // Number of Slices (read only)
  private var __numberOfTx                  = 0                             // Number of TX (read only)
  // O
  private var __oscillator                  = ""                            //
  // P
  private var __psocMbPa100Version          = ""                            // Power amplifier software version
  private var __psocMbtrxVersion            = ""                            // System supervisor software version
  // R
  private var __radioModel                  = ""                            // Radio Model (e.g. FLEX-6500) (read only)
  private var __radioOptions                = ""                            // (read only)
  private var __radioScreenSaver            = ""                            // (read only)
  private var __region                      = ""                            // (read only)
  private var __remoteOnEnabled             = false                         // Remote Power On enable
  private var __rttyMark                    = 0                             // RTTY mark default
  // S
  private var __setting                     = ""                            //
  private var __smartSdrMB                  = ""                            // Microburst main CPU software version
  private var __snapTuneEnabled             = false                         // Snap tune enable
  private var __softwareVersion             = ""                            // (read only)
  private var __startOffset                 = true                          //
  private var __state                       = ""                            //
  private var __staticGateway               = ""                            // Static Gateway address
  private var __staticIp                    = ""                            // Static IpAddress
  private var __staticNetmask               = ""                            // Static Netmask
  // T
  private var __tnfEnabled                  = false                         // TNF's enable
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Radio Class
  ///
  /// - Parameters:
  ///   - api:        an Api instance
  ///
  public init(api: Api, objectQ: DispatchQueue) {
    
    _api = api
    _objectQ = objectQ

    super.init()

    _api.delegate = self
    
    // initialize the static models (only one of each is ever created)
    atu = Atu(queue: _objectQ)
    cwx = Cwx(queue: _objectQ)
    gps = Gps(queue: _objectQ)
    interlock = Interlock(queue: _objectQ)
    profile = Profile(queue: _objectQ)
    transmit = Transmit(queue: _objectQ)
    wan = Wan(queue: _objectQ)
    waveform = Waveform(queue: _objectQ)
    
    // initialize Equalizers (use the newer "sc" type)
    equalizers[.rxsc] = Equalizer(id: Equalizer.EqType.rxsc.rawValue, queue: _objectQ)
    equalizers[.txsc] = Equalizer(id: Equalizer.EqType.txsc.rawValue, queue: _objectQ)
  }
  /// Remove all Radio objects
  ///
  public func removeAll() {
    
    // ----- remove all objects -----
    
    // clear all collections
    //      NOTE: order is important
    
    for (_, audioStream) in _audioStreams {
      // notify all observers
      NC.post(.audioStreamWillBeRemoved, object: audioStream as Any?)
    }
    audioStreams.removeAll()
    
//    for (_, iqStream) in _iqStreams {
//      // notify all observers
//      NC.post(.iqStreamWillBeRemoved, object: iqStream as Any?)
//    }
//    iqStreams.removeAll()
    
    for (_, micAudioStream) in _micAudioStreams {
      // notify all observers
      NC.post(.micAudioStreamWillBeRemoved, object: micAudioStream as Any?)
    }
    micAudioStreams.removeAll()
    
    for (_, txAudioStream) in _txAudioStreams {
      // notify all observers
      NC.post(.txAudioStreamWillBeRemoved, object: txAudioStream as Any?)
    }
    txAudioStreams.removeAll()
    
    for (_, opusStream) in _opusStreams {
      // notify all observers
      NC.post(.opusWillBeRemoved, object: opusStream as Any?)
    }
    opusStreams.removeAll()
    
    for (_, tnf) in _tnfs {
      // notify all observers
      NC.post(.tnfWillBeRemoved, object: tnf as Any?)
    }
    tnfs.removeAll()
    
    for (_, slice) in _slices {
      // notify all observers
      NC.post(.sliceWillBeRemoved, object: slice as Any?)
    }
    slices.removeAll()
    
    for (_, panadapter) in _panadapters {
      
      let waterfallId = panadapter.waterfallId
      let waterfall = waterfalls[waterfallId]
      
      // notify all observers
      NC.post(.panadapterWillBeRemoved, object: panadapter as Any?)
      
      NC.post(.waterfallWillBeRemoved, object: waterfall as Any?)
    }
    panadapters.removeAll()
    waterfalls.removeAll()
    
    NC.post(.globalProfileWillBeRemoved, object: profile.globalProfileList as Any?)
    profile.globalProfileList.removeAll()

    NC.post(.micProfileWillBeRemoved, object: profile.micProfileList as Any?)
    profile.micProfileList.removeAll()

    NC.post(.txProfileWillBeRemoved, object: profile.txProfileList as Any?)
    profile.txProfileList.removeAll()

    equalizers.removeAll()
    
    memories.removeAll()
    
    meters.removeAll()
    
    replyHandlers.removeAll()
    
    usbCables.removeAll()
    
    xvtrs.removeAll()
    
    nickname = ""
    _smartSdrMB = ""
    _psocMbtrxVersion = ""
    _psocMbPa100Version = ""
    _fpgaMbVersion = ""
    
    // clear lists
    antennaList.removeAll()
    micList.removeAll()
    rfGainList.removeAll()
    sliceList.removeAll()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  // --------------------------------------------------------------------------------
  //      Second level parsers
  //      Note: All are executed on the parseQ
  // --------------------------------------------------------------------------------
  
  /// Parse a Message. format: <messageNumber>|<messageText>
  ///
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  ///
  private func parseMessage(_ commandSuffix: String) {
    
    // separate it into its components
    let components = commandSuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted messages
    if components.count < 2 {
      
      Log.sharedInstance.msg("Incomplete message, c\(commandSuffix)", level: .debug, function: #function, file: #file, line: #line)
      return
    }
    // bits 24-25 are the errorCode???
    let msgNumber = UInt32(components[0]) ?? 0
    let errorCode = Int((msgNumber & 0x03000000) >> 24)
    let msgText = components[1]
    
    // log it
    Log.sharedInstance.msg(msgText, level: MessageLevel(rawValue: errorCode) ?? MessageLevel.error, function: #function, file: #file, line: #line)
    
    // FIXME: Take action on some/all errors?
  }
  /// Parse a Reply. format: <sequenceNumber>|<hexResponse>|<message>[|<debugOutput>]
  ///
  /// - Parameters:
  ///   - commandSuffix:      a Reply Suffix
  ///
  private func parseReply(_ replySuffix: String) {
    
    // separate it into its components
    let components = replySuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted replies
    if components.count < 2 {
      
      Log.sharedInstance.msg("Incomplete reply, r\(replySuffix)", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    
    // is there an Object expecting to be notified?
    if let replyTuple = replyHandlers[ components[0] ] {
      
      // YES, an Object is waiting for this reply, send the Command to the Handler on that Object
      
      let command = replyTuple.command
      // was a Handler specified?
      if let handler = replyTuple.replyTo {
        
        // YES, call the Handler
        handler(command, components[0], components[1], (components.count == 3) ? components[2] : "")
        
      } else {
        
        // send it to the default reply handler
        defaultReplyHandler(replyTuple.command, seqNum: "", responseValue: components[1], reply: replySuffix)
      }
      // Remove the object from the notification list
      replyHandlers[components[0]] = nil
      
      
    } else {
      
      // no Object is waiting for this reply, log it if it is a non-zero Reply (i.e a possible error)
      if components[1] != Api.kNoError {
        Log.sharedInstance.msg("Unhandled non-zero reply, c\(components[0]), r\(replySuffix), \(flexErrorString(errorCode: components[1]))", level: .warning, function: #function, file: #file, line: #line)
      }
    }
  }
  /// Parse a Status. format: <apiHandle>|<message>, where <message> is of the form: <msgType> <otherMessageComponents>
  ///
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  ///
  private func parseStatus(_ commandSuffix: String) {
    
    // separate it into its components ( [0] = <apiHandle>, [1] = <remainder> )
    var components = commandSuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted status
    guard components.count > 1 else {
      
      Log.sharedInstance.msg("Incomplete status, c\(commandSuffix)", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    // find the space & get the msgType
    let spaceIndex = components[1].index(of: " ")!
    let msgType = String(components[1][..<spaceIndex])
    
    // everything past the msgType is in the remainder
    let remainderIndex = components[1].index(after: spaceIndex)
    let remainder = String(components[1][remainderIndex...])
    
    // Check for unknown Message Types
    guard let token = StatusToken(rawValue: msgType)  else {
      
      // unknown Message Type, log it and ignore the message
      Log.sharedInstance.msg("Unknown token - \(msgType)", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    
    
    // FIXME: file, mixer & turf Not currently implemented
    
    
    // Known Message Types, in alphabetical order
    switch token {
      
    case .amplifier:
      // FIXME: Need format(s)
      Amplifier.parseStatus(remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kRemoved))
      
    case .audioStream:
      //      format: <AudioStreamId> <key=value> <key=value> ...<key=value>
      AudioStream.parseStatus(remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kNotInUse))
      
    case .atu:
      //      format: <key=value> <key=value> ...<key=value>
      atu.parseProperties( remainder.keyValuesArray() )
      
    case .client:
      //      kv                0         1            2
      //      format: client <handle> connected
      //      format: client <handle> disconnected <forced=1/0>      
      parseClient(remainder.keyValuesArray(), radio: self, queue: _objectQ)
      
    case .cwx:
      // replace some characters to avoid parsing conflicts
      cwx.parseProperties( remainder.fix().keyValuesArray() )
      
    case .daxiq:
      //      format: <daxChannel> <key=value> <key=value> ...<key=value>
      //            parseDaxiq( remainder.keyValuesArray())
      
      break // obsolete token, included to prevent log messages
      
    case .display:
      //     format: <displayType> <streamId> <key=value> <key=value> ...<key=value>
      let keyValues = remainder.keyValuesArray()
      
      // what Display Type is it?
      switch keyValues[0].key {
      case DisplayToken.panadapter.rawValue:
        Panadapter.parseStatus(keyValues, radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kRemoved))
        
      case DisplayToken.waterfall.rawValue:
        Waterfall.parseStatus(keyValues, radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kRemoved))
        
      default:
        // unknown Display Type, log it and ignore the message
        Log.sharedInstance.msg("Unknown Display - \(keyValues[0].key)", level: .debug, function: #function, file: #file, line: #line)
      }
      
    case .eq:
      //      format: txsc <key=value> <key=value> ...<key=value>
      //      format: rxsc <key=value> <key=value> ...<key=value>
      Equalizer.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ )
      
    case .file:
      
      Log.sharedInstance.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
      
    case .gps:
      //     format: <key=value>#<key=value>#...<key=value>
      gps.parseProperties( remainder.keyValuesArray(delimiter: "#") )
      
    case .interlock:
      //      format: <key=value> <key=value> ...<key=value>
      interlock.parseProperties( remainder.keyValuesArray())
      
    case .memory:
      //      format: <memoryId> <key=value>,<key=value>,...<key=value>
      Memory.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kRemoved))
      
    case .meter:
      //     format: <meterNumber.key=value>#<meterNumber.key=value>#...<meterNumber.key=value>
      Meter.parseStatus( remainder.keyValuesArray(delimiter: "#"), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kRemoved))
      
    case .micAudioStream:
      //      format: <MicAudioStreamId> <key=value> <key=value> ...<key=value>
      MicAudioStream.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kNotInUse))
      
    case .mixer:
      
      Log.sharedInstance.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
      
    case .opusStream:
      //     format: <opusId> <key=value> <key=value> ...<key=value>
      Opus.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ)
      
    case .profile:
      //     format: global list=<value>^<value>^...<value>^
      //     format: global current=<value>
      //     format: tx list=<value>^<value>^...<value>^
      //     format: tx current=<value>
      //     format: mic list=<value>^<value>^...<value>^
      //     format: mic current=<value>
      profile.parseProperties( remainder.keyValuesArray(delimiter: "="))
      
    case .radio:
      //     format: <key=value> <key=value> ...<key=value>
      parseProperties( remainder.keyValuesArray())
      
    case .slice:
      //     format: <sliceId> <key=value> <key=value> ...<key=value>
      xLib6000.Slice.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kNotInUse))
      
    case .stream:
      //     format: <streamId> <key=value> <key=value> ...<key=value>
      IqStream.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kNotInUse))
      
    case .tnf:
      //     format: <tnfId> <key=value> <key=value> ...<key=value>
      Tnf.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kRemoved))
      
    case .transmit:
      //      format: <key=value> <key=value> ...<key=value>
      transmit.parseProperties( remainder.keyValuesArray())
      
    case .turf:
      
      Log.sharedInstance.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
      
    case .txAudioStream:
      //      format: <TxAudioStreamId> <key=value> <key=value> ...<key=value>
      TxAudioStream.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kNotInUse))
      
    case .usbCable:
      //      format:
      UsbCable.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ)
      
    case .wan:
      wan.parseProperties( remainder.keyValuesArray() )
      
    case .waveform:
      //      format: <key=value> <key=value> ...<key=value>
      waveform.parseProperties( remainder.keyValuesArray())
      
    case .xvtr:
      //      format: <name> <key=value> <key=value> ...<key=value>
      Xvtr.parseStatus( remainder.keyValuesArray(), radio: self, queue: _objectQ, inUse: !remainder.contains(Api.kNotInUse))
    }
  }
  /// Parse a Client status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  private func parseClient(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    
    guard keyValues.count >= 2 else {
      
      Log.sharedInstance.msg("Invalid client status", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    // guard that the message has my API Handle
    guard ("0x" + _api.connectionHandle == keyValues[0].key) else { return }
    
    // what is the message?
    if keyValues[1].key == "connected" {
      // Connected
      _api.setConnectionState(.clientConnected)
      
    } else if (keyValues[1].key == "disconnected" && keyValues[2].key == "forced") {
      // FIXME: Handle the disconnect?
      // Disconnected
      Log.sharedInstance.msg("Disconnect, forced=\(keyValues[2].value)", level: .verbose, function: #function, file: #file, line: #line)
      
    } else {
      // Unrecognized
      Log.sharedInstance.msg("Unprocessed message, \(remainder)", level: .warning, function: #function, file: #file, line: #line)
    }
  }
  /// Parse the Reply to an Info command, reply format: <key=value> <key=value> ...<key=value>
  ///
  /// - Parameters:
  ///   - properties:          a KeyValuesArray
  ///
  private func parseInfoReply(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Keys
      guard let token = InfoToken(rawValue: property.key) else {
        // unknown Key, log it and ignore this Key
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .atuPresent:
        _api.update(self, property: &atu._status, value: property.value.bValue(), key: "atuPresent")

      case .callsign:
        _api.update(self, property: &_callsign, value: property.value.replacingOccurrences(of: "\"", with:""), key: "callsign")

      case .chassisSerial:
        _api.update(self, property: &_chassisSerial, value: property.value.replacingOccurrences(of: "\"", with:""), key: "chassisSerial")

      case .gateway:
        _api.update(self, property: &_gateway, value: property.value.replacingOccurrences(of: "\"", with:""), key: "gateway")

      case .gps:
        _api.update(self, property: &gps._status, value: property.value.bValue(), key: "gpsPresent")

      case .ipAddress:
        _api.update(self, property: &_ipAddress, value: property.value.replacingOccurrences(of: "\"", with:""), key: "ipAddress")

      case .location:
        _api.update(self, property: &_location, value: property.value.replacingOccurrences(of: "\"", with:""), key: "location")

      case .macAddress:
        _api.update(self, property: &_macAddress, value: property.value.replacingOccurrences(of: "\"", with:""), key: "macAddress")

      case .model:
         _api.update(self, property: &_radioModel, value: property.value.replacingOccurrences(of: "\"", with:""), key: "radioModel")

      case .netmask:
        _api.update(self, property: &_netmask, value: property.value.replacingOccurrences(of: "\"", with:""), key: "netmask")

      case .name:
        _api.update(self, property: &_nickname, value: property.value.replacingOccurrences(of: "\"", with:""), key: "nickname")

      case .numberOfScus:
        _api.update(self, property: &_numberOfScus, value: property.value.iValue(), key: "numberOfScus")

      case .numberOfSlices:
        _api.update(self, property: &_numberOfSlices, value: property.value.iValue(), key: "numberOfSlices")

      case .numberOfTx:
        _api.update(self, property: &_numberOfTx, value: property.value.iValue(), key: "numberOfTx")

      case .options:
        _api.update(self, property: &_radioOptions, value: property.value.replacingOccurrences(of: "\"", with:""), key: "radioOptions")

      case .region:
        _api.update(self, property: &_region, value: property.value.replacingOccurrences(of: "\"", with:""), key: "region")

      case .screensaver:
        _api.update(self, property: &_radioScreenSaver, value: property.value.replacingOccurrences(of: "\"", with:""), key: "radioScreenSaver")

      case .softwareVersion:
        _api.update(self, property: &_softwareVersion, value: property.value.replacingOccurrences(of: "\"", with:""), key: "softwareVersion")
      }
    }
  }
  /// Parse the Reply to a Client Ip command, reply format: <key=value> <key=value> ...<key=value>
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray
  ///
  private func parseIpReply(_ keyValues: KeyValuesArray) {
    
    // save the returned ip address
    _clientIp = keyValues[0].key
    
  }
  /// Parse the Reply to a Meter list command, reply format: <value>,<value>,...<value>
  ///
  /// - Parameters:
  ///   - reply:          the reply
  ///
//  private func parseMeterListReply(_ reply: String) {
//
//    // nested function to add meter subscriptions
//    func addMeter(id: String, keyValues: KeyValuesArray) {
//
//      // is the meter Short Name valid?
//      if let shortName = Api.MeterShortName(rawValue: keyValues[2].value.lowercased()) {
//        
//        // YES, is it in the list needing subscription?
//        if _metersToSubscribe.contains(shortName) {
//          
//          // YES, send a subscription command
//          Meter.subscribe(id: id)
//        }
//      }
//    }
//    // drop the "meter " string
//    let meters = String(reply.dropFirst(6))
//    let keyValues = meters.keyValuesArray(delimiter: "#")
//
//    var meterKeyValues = KeyValuesArray()
//
//    // extract the first Meter Number
//    var id = keyValues[0].key.components(separatedBy: ".")[0]
//
//    // loop through the kv pairs separating them into individual meters
//    for (i, kv) in keyValues.enumerated() {
//
//      // is this the start of a different meter?
//      if id != kv.key.components(separatedBy: ".")[0] {
//
//        // YES, add the current meter
//        addMeter(id: id, keyValues: meterKeyValues)
//
//        // recycle the keyValues
//        meterKeyValues.removeAll(keepingCapacity: true)
//
//        // get the new meter id
//        id = keyValues[i].key.components(separatedBy: ".")[0]
//
//      }
//      // add the current kv pair to the current set of meter kv pairs
//      meterKeyValues.append(keyValues[i])
//    }
//    // add the final meter
//    addMeter(id: id, keyValues: meterKeyValues)
//  }
  /// Parse the Reply to a Version command, reply format: <key=value>#<key=value>#...<key=value>
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray
  ///
  private func parseVersionReply(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Tokens
      guard let token = VersionToken(rawValue: property.key) else {
        // Unknown Token, log it and ignore this Token
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .smartSdrMB:
        _api.update(self, property: &_smartSdrMB, value: property.value, key: "smartSdrMB")

      case .psocMbTrx:
        _api.update(self, property: &_psocMbtrxVersion, value: property.value, key: "psocMbtrxVersion")

      case .psocMbPa100:
        _api.update(self, property: &_psocMbPa100Version, value: property.value, key: "psocMbPa100Version")

      case .fpgaMb:
        _api.update(self, property: &_fpgaMbVersion, value: property.value, key: "fpgaMbVersion")
      }
    }
  }
  
  // --------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     executes on the radioQ
  
  /// Parse a Radio status message
  ///
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    var filterSharpness = false
    var cw = false
    var digital = false
    var voice = false
    var staticNetParams = false
    var oscillator = false
    
    // FIXME: What about a 6700 with two scu's?
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = RadioToken(rawValue: property.key)  else {
        
        // unknown Display Type, log it and ignore this token
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .autoLevel:
        if filterSharpness && cw {
          _api.update(self, property: &_filterCwAutoLevel, value: property.value.iValue(), key: "filterCwAutoLevel")
          cw = false
        }
        if filterSharpness && digital {
          _api.update(self, property: &_filterDigitalAutoLevel, value: property.value.iValue(), key: "filterDigitalAutoLevel")
          digital = false
        }
        if filterSharpness && voice {
          _api.update(self, property: &_filterVoiceAutoLevel, value: property.value.iValue(), key: "filterVoiceAutoLevel")
          voice = false
        }
        filterSharpness = false
        
      case .backlight:
        _api.update(self, property: &_backlight, value: property.value.iValue(), key: "backlight")

      case .bandPersistenceEnabled:
        _api.update(self, property: &_bandPersistenceEnabled, value: property.value.bValue(), key: "bandPersistenceEnabled")

      case .binauralRxEnabled:
        _api.update(self, property: &_binauralRxEnabled, value: property.value.bValue(), key: "binauralRxEnabled")

      case .calFreq:
        _api.update(self, property: &_calFreq, value: property.value.iValue(), key: "calFreq")

      case .callsign:
        _api.update(self, property: &_callsign, value: property.value, key: "callsign")

      case .cw, .CW:
        cw = true
        
      case .digital, .DIGITAL:
        digital = true
        
      case .enforcePrivateIpEnabled:
        _api.update(self, property: &_enforcePrivateIpEnabled, value: property.value.bValue(), key: "enforcePrivateIpEnabled")

      case .filterSharpness:
        filterSharpness = true
        
      case .freqErrorPpb:
         _api.update(self, property: &_freqErrorPpb, value: property.value.iValue(), key: "freqErrorPpb")

      case .fullDuplexEnabled:
        _api.update(self, property: &_fullDuplexEnabled, value: property.value.bValue(), key: "fullDuplexEnabled")

      case .gateway:
        if staticNetParams {
          _api.update(self, property: &_staticGateway, value: property.value, key: "staticGateway")
        }
        
      case .headphoneGain:
        _api.update(self, property: &_headphoneGain, value: property.value.iValue(), key: "headphoneGain")

      case .headphoneMute:
        _api.update(self, property: &_headphoneMute, value: property.value.bValue(), key: "headphoneMute")

      case .ip:
        if staticNetParams {
          _api.update(self, property: &_staticIp, value: property.value, key: "staticIp")
        }
        
      case .level:
        if filterSharpness && cw {
          _api.update(self, property: &_filterCwLevel, value: property.value.iValue(), key: "filterCwLevel")
          cw = false
        }
        if filterSharpness && digital {
          _api.update(self, property: &_filterDigitalLevel, value: property.value.iValue(), key: "filterDigitalLevel")
          digital = false
        }
        if filterSharpness && voice {
          _api.update(self, property: &_filterVoiceLevel, value: property.value.iValue(), key: "filterVoiceLevel")
          voice = false
        }
        filterSharpness = false
        
      case .lineoutGain:
         _api.update(self, property: &_lineoutGain, value: property.value.iValue(), key: "lineoutGain")

      case .lineoutMute:
        _api.update(self, property: &_lineoutMute, value: property.value.bValue(), key: "lineoutMute")

      case .locked:
        if oscillator {
          _api.update(self, property: &_locked, value: property.value.bValue(), key: "locked")
        }
        
      case .netmask:
        if staticNetParams {
          _api.update(self, property: &_staticNetmask, value: property.value, key: "staticNetmask")
          staticNetParams = false
        }
        
      case .nickname:
        _api.update(self, property: &_nickname, value: property.value, key: "nickname")

      case .oscillator:
        oscillator = true
        
      case .panadapters:
        _api.update(self, property: &_availablePanadapters, value: property.value.iValue(), key: "availablePanadapters")

      case .pllDone:
        _api.update(self, property: &_startOffset, value: property.value.bValue(), key: "startOffset")

      case .remoteOnEnabled:
        _api.update(self, property: &_remoteOnEnabled, value: property.value.bValue(), key: "remoteOnEnabled")

      case .rttyMark:
        _api.update(self, property: &_rttyMark, value: property.value.iValue(), key: "rttyMark")

      case .setting:
        if oscillator {
          _api.update(self, property: &_setting, value: property.value, key: "setting")
        }
        
      case .slices:
        _api.update(self, property: &_availableSlices, value: property.value.iValue(), key: "availableSlices")

      case .snapTuneEnabled:
        _api.update(self, property: &_snapTuneEnabled, value: property.value.bValue(), key: "snapTuneEnabled")

      case .state:
        if oscillator {
          _api.update(self, property: &_state, value: property.value, key: "state")
        }
        
      case .staticNetParams:
        staticNetParams = true
        
      case .tnfEnabled:
        _api.update(self, property: &_tnfEnabled, value: property.value.bValue(), key: "tnfEnabled")

      case .voice, .VOICE:
        voice = true
        
      }
    }
    // is the Radio initialized?
    if !_radioInitialized {
      
      // YES, the Radio (hardware) has acknowledged this Radio
      _radioInitialized = true
      
      // notify all observers
      NC.post(.radioHasBeenAdded, object: self as Any?)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Api delegate methods
  
  /// Parse inbound Tcp messages
  ///
  /// - Parameter msg:        the Message String
  ///
  public func receivedMessage(_ msg: String) {
    // arrives on the parseQ
    
    // get all except the first character
    let suffix = String(msg.dropFirst())
    
    // switch on the first character
    switch msg[msg.startIndex] {
      
    case "H", "h":   // Handle type
      _api.connectionHandle = suffix
      
    case "M", "m":   // Message Type
      parseMessage(suffix)
      
    case "R", "r":   // Reply Type
      parseReply(suffix)
      
    case "S", "s":   // Status type
      parseStatus(suffix)
      
    case "V", "v":   // Version Type
      _hardwareVersion = suffix
      
    default:    // Unknown Type
      Log.sharedInstance.msg("Unexpected message - " + msg, level: .debug, function: #function, file: #file, line: #line)
    }
  }
  /// Process outbound Tcp messages
  ///
  /// - Parameter msg:    the Message text
  ///
  public func sentMessage(_ text: String) {
    // unused in xLib6000
  }
  /// Process a message from the Api
  ///
  /// - Parameters:
  ///   - text:           message test
  ///   - level:          MessageLevel
  ///   - function:       function originating the message
  ///   - file:           file originating the message
  ///   - line:           line originating the message
  ///
  public func apiMessage(_ text: String, level: MessageLevel, function: StaticString, file: StaticString, line: Int) {
    
    // log the message
    Log.sharedInstance.msg(text, level: level, function: function, file: file, line: line)
  }
  
  /// Add a Reply Handler for a specific Sequence/Command
  ///
  /// - Parameters:
  ///   - sequenceId:     sequence number of the Command
  ///   - replyTuple:     a Reply Tuple
  ///
  public func addReplyHandler(_ seqNumber: SequenceId, replyTuple: ReplyTuple) {
    
    // add the handler
    replyHandlers[seqNumber] = replyTuple
  }
  /// Process the Reply to a command, reply format: <value>,<value>,...<value>
  ///
  /// - Parameters:
  ///   - command:        the original command
  ///   - seqNum:         the Sequence Number of the original command
  ///   - responseValue:  the response value
  ///   - reply:          the reply
  ///
  public func defaultReplyHandler(_ command: String, seqNum: String, responseValue: String, reply: String) {
    
    guard responseValue == Api.kNoError else {
      
      // ignore non-zero reply from "client program" command
      if !command.hasPrefix(Api.Command.clientProgram.rawValue) {
        
        // Anything other than 0 is an error, log it and ignore the Reply
        Log.sharedInstance.msg(command + ", non-zero reply - \(reply)", level: .error, function: #function, file: #file, line: #line)
      }
      return
    }

    // which command?
    switch command {
      
    case Api.Command.clientIp.rawValue:
      // process the reply
      parseIpReply( reply.keyValuesArray() )
      
    case Api.Command.info.rawValue:
      // process the reply
      parseInfoReply( reply.keyValuesArray() )
      
    case Api.Command.antList.rawValue:
      // save the list
      antennaList = reply.valuesArray( delimiter: "," )
      
//    case Api.Command.meterList.rawValue:                  // no longer in use
//      // process the reply
//      parseMeterListReply( reply )
      
    case Api.Command.micList.rawValue:
      // save the list
      micList = reply.valuesArray(  delimiter: "," )
      
    case xLib6000.Slice.kListCmd:
      // save the list
      sliceList = reply.valuesArray()
      
    case Radio.kUptimeCmd:
      // save the returned Uptime (seconds)
      uptime = Int(reply) ?? 0
      
    case Api.Command.version.rawValue:
      // process the reply
      parseVersionReply( reply.keyValuesArray(delimiter: "#") )

//    case Api.Command.profileMic.rawValue:
//      // save the list
//      profile.profiles[.mic] = reply.valuesArray(  delimiter: "^" )
//
//    case Api.Command.profileGlobal.rawValue:
//      // save the list
//      profile.profiles[.global] = reply.valuesArray(  delimiter: "^" )
//
//    case Api.Command.profileTx.rawValue:
//      // save the list
//      profile.profiles[.tx] = reply.valuesArray(  delimiter: "^" )
      

    default:
      
      if command.hasPrefix(Panadapter.kCmd + "create") {
        
        // ignore, Panadapter & Waterfall will be created when Status reply is seen
        break
        
      } else if command.hasPrefix("tnf " + "r") {

        // parse the reply
        let components = command.components(separatedBy: " ")
        
        // if it's valid and the Tnf has not been removed
        if components.count == 3 && _api.radio?.tnfs[components[2]] != nil{
          
          // notify all observers
          NC.post(.tnfWillBeRemoved, object: _api.radio?.tnfs[components[2]] as Any?)

          // remove the Tnf
          _api.radio?.tnfs[components[2]] = nil
        }
        
      } else if command.hasPrefix(AudioStream.kStreamCreateCmd + "dax=") {
        
        // TODO: add code
        break
        
      } else if command.hasPrefix(AudioStream.kStreamCreateCmd + "daxmic") {
        
        // TODO: add code
        break
        
      } else if command.hasPrefix(AudioStream.kStreamCreateCmd + "daxtx") {
        
        // TODO: add code
        break
        
      } else if command.hasPrefix(IqStream.kStreamCreateCmd + "daxiq") {
        
        // TODO: add code
        break
        
      } else if command.hasPrefix(xLib6000.Slice.kCmd + "get_error"){
        
        // save the errors, format: <rx_error_value>,<tx_error_value>
        sliceErrors = reply.valuesArray( delimiter: "," )
      }
    }
  }
  /// Process received UDP Vita packets
  ///
  /// - Parameter vitaPacket:       a Vita packet
  ///
  public func vitaParser(_ vitaPacket: Vita) {
    
    _streamQ.async { [unowned self ] in
      
      // Pass the stream to the appropriate object (checking for existence of the object first)
      switch (vitaPacket.classCode) {
        
      case .daxAudio where self.audioStreams[vitaPacket.streamId] != nil:
        // Dax Slice Audio
        self.audioStreams[vitaPacket.streamId]!.vitaProcessor(vitaPacket)
        
      case .daxAudio where self.micAudioStreams[vitaPacket.streamId] != nil:
        // Dax Microphone Audio
        self.micAudioStreams[vitaPacket.streamId]!.vitaProcessor(vitaPacket)
        
      case .daxIq24 where self.iqStreams[vitaPacket.streamId] != nil,
           .daxIq48 where self.iqStreams[vitaPacket.streamId] != nil,
           .daxIq96 where self.iqStreams[vitaPacket.streamId] != nil,
           .daxIq192 where self.iqStreams[vitaPacket.streamId] != nil:
        // Dax IQ
        self.iqStreams[vitaPacket.streamId]!.vitaProcessor(vitaPacket)
        
      case .meter:
        // Meter - unlike other streams, the Meter stream contains multiple Meters
        //         and must be processed by a class method on the Meter object
        Meter.vitaProcessor(vitaPacket)
        
      case .opus where self.opusStreams[vitaPacket.streamId] != nil:
        // Opus
        self.opusStreams[vitaPacket.streamId]!.vitaProcessor( vitaPacket )
        
      case .panadapter where self.panadapters[vitaPacket.streamId] != nil:
        // Panadapter
        self.panadapters[vitaPacket.streamId]!.vitaProcessor(vitaPacket)
        
      case .waterfall where self.waterfalls[vitaPacket.streamId] != nil:
        // Waterfall
        self.waterfalls[vitaPacket.streamId]!.vitaProcessor(vitaPacket)
        
      default:
        // log the error
        Log.sharedInstance.msg("UDP Stream error, no object for - \(vitaPacket.classCode.description()) (\(vitaPacket.streamId.hex))", level: .error, function: #function, file: #file, line: #line)
      }
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Radio Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Display tokens
//              - Equalizer Apf tokens
//              - Info reply tokens
//              - Radio tokens
//              - Status tokens
//              - Version reply tokens
//              - Radio related enums
//              - Type aliases
// --------------------------------------------------------------------------------

extension Radio {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _apfEnabled: Bool {
    get { return _objectQ.sync { __apfEnabled } }
    set { _objectQ.sync(flags: .barrier) { __apfEnabled = newValue } } }
  
  internal var _apfQFactor: Int {
    get { return _objectQ.sync { __apfQFactor } }
    set { _objectQ.sync(flags: .barrier) { __apfQFactor = newValue.bound(Api.kMinApfQ, Api.kMaxApfQ) } } }
  
  internal var _apfGain: Int {
    get { return _objectQ.sync { __apfGain } }
    set { _objectQ.sync(flags: .barrier) { __apfGain = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _availablePanadapters: Int {
    get { return _objectQ.sync { __availablePanadapters } }
    set { _objectQ.sync(flags: .barrier) { __availablePanadapters = newValue } } }
  
  internal var _availableSlices: Int {
    get { return _objectQ.sync { __availableSlices } }
    set { _objectQ.sync(flags: .barrier) { __availableSlices = newValue } } }
  
  internal var _backlight: Int {
    get { return _objectQ.sync { __backlight } }
    set { _objectQ.sync(flags: .barrier) { __backlight = newValue } } }
  
  internal var _bandPersistenceEnabled: Bool {
    get { return _objectQ.sync { __bandPersistenceEnabled } }
    set { _objectQ.sync(flags: .barrier) { __bandPersistenceEnabled = newValue } } }
  
  internal var _binauralRxEnabled: Bool {
    get { return _objectQ.sync { __binauralRxEnabled } }
    set { _objectQ.sync(flags: .barrier) { __binauralRxEnabled = newValue } } }
  
  internal var _calFreq: Int {
    get { return _objectQ.sync { __calFreq } }
    set { _objectQ.sync(flags: .barrier) { __calFreq = newValue } } }
  
  internal var _callsign: String {
    get { return _objectQ.sync { __callsign } }
    set { _objectQ.sync(flags: .barrier) { __callsign = newValue } } }
  
  internal var _chassisSerial: String {
    get { return _objectQ.sync { __chassisSerial } }
    set { _objectQ.sync(flags: .barrier) { __chassisSerial = newValue } } }
  
  internal var _clientIp: String {
    get { return _objectQ.sync { __clientIp } }
    set { _objectQ.sync(flags: .barrier) { __clientIp = newValue } } }
  
  internal var _daxIqAvailable: Int {
    get { return _objectQ.sync { __daxIqAvailable } }
    set { _objectQ.sync(flags: .barrier) { __daxIqAvailable = newValue } } }
  
  internal var _daxIqCapacity: Int {
    get { return _objectQ.sync { __daxIqCapacity } }
    set { _objectQ.sync(flags: .barrier) { __daxIqCapacity = newValue } } }
  
  internal var _enforcePrivateIpEnabled: Bool {
    get { return _objectQ.sync { __enforcePrivateIpEnabled } }
    set { _objectQ.sync(flags: .barrier) { __enforcePrivateIpEnabled = newValue } } }
  
  internal var _filterCwAutoLevel: Int {
    get { return _objectQ.sync { __filterCwAutoLevel } }
    set { _objectQ.sync(flags: .barrier) { __filterCwAutoLevel = newValue } } }
  
  internal var _filterDigitalAutoLevel: Int {
    get { return _objectQ.sync { __filterDigitalAutoLevel } }
    set { _objectQ.sync(flags: .barrier) { __filterDigitalAutoLevel = newValue } } }
  
  internal var _filterVoiceAutoLevel: Int {
    get { return _objectQ.sync { __filterVoiceAutoLevel } }
    set { _objectQ.sync(flags: .barrier) { __filterVoiceAutoLevel = newValue } } }
  
  internal var _filterCwLevel: Int {
    get { return _objectQ.sync { __filterCwLevel } }
    set { _objectQ.sync(flags: .barrier) { __filterCwLevel = newValue } } }
  
  internal var _filterDigitalLevel: Int {
    get { return _objectQ.sync { __filterDigitalLevel } }
    set { _objectQ.sync(flags: .barrier) { __filterDigitalLevel = newValue } } }
  
  internal var _filterVoiceLevel: Int {
    get { return _objectQ.sync { __filterVoiceLevel } }
    set { _objectQ.sync(flags: .barrier) { __filterVoiceLevel = newValue } } }
  
  internal var _fpgaMbVersion: String {
    get { return _objectQ.sync { __fpgaMbVersion } }
    set { _objectQ.sync(flags: .barrier) { __fpgaMbVersion = newValue } } }
  
  internal var _freqErrorPpb: Int {
    get { return _objectQ.sync { __freqErrorPpb } }
    set { _objectQ.sync(flags: .barrier) { __freqErrorPpb = newValue } } }
  
  internal var _fullDuplexEnabled: Bool {
    get { return _objectQ.sync { __fullDuplexEnabled } }
    set { _objectQ.sync(flags: .barrier) { __fullDuplexEnabled = newValue } } }
  
  internal var _gateway: String {
    get { return _objectQ.sync { __gateway } }
    set { _objectQ.sync(flags: .barrier) { __gateway = newValue } } }
  
  internal var _headphoneGain: Int {
    get { return _objectQ.sync { __headphoneGain } }
    set { _objectQ.sync(flags: .barrier) { __headphoneGain = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _headphoneMute: Bool {
    get { return _objectQ.sync { __headphoneMute } }
    set { _objectQ.sync(flags: .barrier) { __headphoneMute = newValue } } }
  
  internal var _ipAddress: String {
    get { return _objectQ.sync { __ipAddress } }
    set { _objectQ.sync(flags: .barrier) { __ipAddress = newValue } } }
  
  internal var _location: String {
    get { return _objectQ.sync { __location } }
    set { _objectQ.sync(flags: .barrier) { __location = newValue } } }
  
  internal var _macAddress: String {
    get { return _objectQ.sync { __macAddress } }
    set { _objectQ.sync(flags: .barrier) { __macAddress = newValue } } }
  
  internal var _lineoutGain: Int {
    get { return _objectQ.sync { __lineoutGain } }
    set { _objectQ.sync(flags: .barrier) { __lineoutGain = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _lineoutMute: Bool {
    get { return _objectQ.sync { __lineoutMute } }
    set { _objectQ.sync(flags: .barrier) { __lineoutMute = newValue } } }
  
  internal var _locked: Bool {
    get { return _objectQ.sync { __locked } }
    set { _objectQ.sync(flags: .barrier) { __locked = newValue } } }
  
  internal var _netmask: String {
    get { return _objectQ.sync { __netmask } }
    set { _objectQ.sync(flags: .barrier) { __netmask = newValue } } }
  
  internal var _nickname: String {
    get { return _objectQ.sync { __nickname } }
    set { _objectQ.sync(flags: .barrier) { __nickname = newValue } } }
  
  internal var _numberOfScus: Int {
    get { return _objectQ.sync { __numberOfScus } }
    set { _objectQ.sync(flags: .barrier) { __numberOfScus = newValue } } }
  
  internal var _numberOfSlices: Int {
    get { return _objectQ.sync { __numberOfSlices } }
    set { _objectQ.sync(flags: .barrier) { __numberOfSlices = newValue } } }
  
  internal var _numberOfTx: Int {
    get { return _objectQ.sync { __numberOfTx } }
    set { _objectQ.sync(flags: .barrier) { __numberOfTx = newValue } } }
  
  internal var _oscillator: String {
    get { return _objectQ.sync { __oscillator } }
    set { _objectQ.sync(flags: .barrier) { __oscillator = newValue } } }
  
  internal var _psocMbPa100Version: String {
    get { return _objectQ.sync { __psocMbPa100Version } }
    set { _objectQ.sync(flags: .barrier) { __psocMbPa100Version = newValue } } }
  
  internal var _psocMbtrxVersion: String {
    get { return _objectQ.sync { __psocMbtrxVersion } }
    set { _objectQ.sync(flags: .barrier) { __psocMbtrxVersion = newValue } } }
  
  internal var _radioModel: String {
    get { return _objectQ.sync { __radioModel } }
    set { _objectQ.sync(flags: .barrier) { __radioModel = newValue } } }
  
  internal var _radioOptions: String {
    get { return _objectQ.sync { __radioOptions } }
    set { _objectQ.sync(flags: .barrier) { __radioOptions = newValue } } }
  
  internal var _radioScreenSaver: String {
    get { return _objectQ.sync { __radioScreenSaver } }
    set { _objectQ.sync(flags: .barrier) { __radioScreenSaver = newValue } } }
  
  internal var _region: String {
    get { return _objectQ.sync { __region } }
    set { _objectQ.sync(flags: .barrier) { __region = newValue } } }
  
  internal var _remoteOnEnabled: Bool {
    get { return _objectQ.sync { __remoteOnEnabled } }
    set { _objectQ.sync(flags: .barrier) { __remoteOnEnabled = newValue } } }
  
  internal var _rttyMark: Int {
    get { return _objectQ.sync { __rttyMark } }
    set { _objectQ.sync(flags: .barrier) { __rttyMark = newValue } } }
  
  internal var _setting: String {
    get { return _objectQ.sync { __setting } }
    set { _objectQ.sync(flags: .barrier) { __setting = newValue } } }
  
  internal var _smartSdrMB: String {
    get { return _objectQ.sync { __smartSdrMB } }
    set { _objectQ.sync(flags: .barrier) { __smartSdrMB = newValue } } }
  
  internal var _snapTuneEnabled: Bool {
    get { return _objectQ.sync { __snapTuneEnabled } }
    set { _objectQ.sync(flags: .barrier) { __snapTuneEnabled = newValue } } }
  
  internal var _softwareVersion: String {
    get { return _objectQ.sync { __softwareVersion } }
    set { _objectQ.sync(flags: .barrier) { __softwareVersion = newValue } } }
  
  internal var _startOffset: Bool {
    get { return _objectQ.sync { __startOffset } }
    set { _objectQ.sync(flags: .barrier) { __startOffset = newValue } } }
  
  internal var _state: String {
    get { return _objectQ.sync { __state } }
    set { _objectQ.sync(flags: .barrier) { __state = newValue } } }
  
  internal var _staticGateway: String {
    get { return _objectQ.sync { __staticGateway } }
    set { _objectQ.sync(flags: .barrier) { __staticGateway = newValue } } }
  
  internal var _staticIp: String {
    get { return _objectQ.sync { __staticIp } }
    set { _objectQ.sync(flags: .barrier) { __staticIp = newValue } } }
  
  internal var _staticNetmask: String {
    get { return _objectQ.sync { __staticNetmask } }
    set { _objectQ.sync(flags: .barrier) { __staticNetmask = newValue } } }
  
  internal var _tnfEnabled: Bool {
    get { return _objectQ.sync { __tnfEnabled } }
    set { _objectQ.sync(flags: .barrier) { __tnfEnabled = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var availablePanadapters: Int {
    return _availablePanadapters }
  
  @objc dynamic public var availableSlices: Int {
    return _availableSlices }
  
  @objc dynamic public var chassisSerial: String {
    return _chassisSerial }
  
  @objc dynamic public var clientIp: String {
    return _clientIp }
  
  @objc dynamic public var daxIqAvailable: Int {
    return _daxIqAvailable }
  
  @objc dynamic public var daxIqCapacity: Int {
    return _daxIqCapacity }
  
  @objc dynamic public var fpgaMbVersion: String {
    return _fpgaMbVersion }
  
  @objc dynamic public var gateway: String {
    return _gateway }
  
  @objc dynamic public var ipAddress: String {
    return _ipAddress }
  
  @objc dynamic public var location: String {
    return _location }
  
  @objc dynamic public var macAddress: String {
    return _macAddress }
  
  @objc dynamic public var netmask: String {
    return _netmask }
  
  @objc dynamic public var numberOfScus: Int {
    return _numberOfScus }
  
  @objc dynamic public var numberOfSlices: Int {
    return _numberOfSlices }
  
  @objc dynamic public var numberOfTx: Int {
    return _numberOfTx }
  
  @objc dynamic public var psocMbPa100Version: String {
    return _psocMbPa100Version }
  
  @objc dynamic public var psocMbtrxVersion: String {
    return _psocMbtrxVersion }
  
  @objc dynamic public var radioModel: String {
    return _radioModel }
  
  @objc dynamic public var radioOptions: String {
    return _radioOptions }
  
  @objc dynamic public var region: String {
    return _region }
  
  @objc dynamic public var smartSdrMB: String {
    return _smartSdrMB }
  
  @objc dynamic public var softwareVersion: String {
    return _softwareVersion }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  // collections
  public var amplifiers: [AmplifierId: Amplifier] {
    get { return _objectQ.sync { _amplifiers } }
    set { _objectQ.sync(flags: .barrier) { _amplifiers = newValue } } }
  
  public var audioStreams: [DaxStreamId: AudioStream] {
    get { return _objectQ.sync { _audioStreams } }
    set { _objectQ.sync(flags: .barrier) { _audioStreams = newValue } } }
  
  public var equalizers: [Equalizer.EqType: Equalizer] {
    get { return _objectQ.sync { _equalizers } }
    set { _objectQ.sync(flags: .barrier) { _equalizers = newValue } } }
  
  public var iqStreams: [DaxStreamId: IqStream] {
    get { return _objectQ.sync { _iqStreams } }
    set { _objectQ.sync(flags: .barrier) { _iqStreams = newValue } } }
  
  public var memories: [MemoryId: Memory] {
    get { return _objectQ.sync { _memories } }
    set { _objectQ.sync(flags: .barrier) { _memories = newValue } } }
  
  public var meters: [MeterId: Meter] {
    get { return _objectQ.sync { _meters } }
    set { _objectQ.sync(flags: .barrier) { _meters = newValue } } }
  
  public var micAudioStreams: [DaxStreamId: MicAudioStream] {
    get { return _objectQ.sync { _micAudioStreams } }
    set { _objectQ.sync(flags: .barrier) { _micAudioStreams = newValue } } }
  
  public var opusStreams: [OpusId: Opus] {
    get { return _objectQ.sync { _opusStreams } }
    set { _objectQ.sync(flags: .barrier) { _opusStreams = newValue } } }
  
  public var panadapters: [PanadapterId: Panadapter] {
    get { return _objectQ.sync { _panadapters } }
    set { _objectQ.sync(flags: .barrier) { _panadapters = newValue } } }
  
  public var replyHandlers: [SequenceId: ReplyTuple] {
    get { return _objectQ.sync { _replyHandlers } }
    set { _objectQ.sync(flags: .barrier) { _replyHandlers = newValue } } }
  
  public var slices: [SliceId: Slice] {
    get { return _objectQ.sync { _slices } }
    set { _objectQ.sync(flags: .barrier) { _slices = newValue } } }
  
  public var tnfs: [TnfId: Tnf] {
    get { return _objectQ.sync { _tnfs } }
    set { _objectQ.sync(flags: .barrier) { _tnfs = newValue } } }
  
  public var txAudioStreams: [DaxStreamId: TxAudioStream] {
    get { return _objectQ.sync { _txAudioStreams } }
    set { _objectQ.sync(flags: .barrier) { _txAudioStreams = newValue } } }
  
  public var waterfalls: [WaterfallId: Waterfall] {
    get { return _objectQ.sync { _waterfalls } }
    set { _objectQ.sync(flags: .barrier) { _waterfalls = newValue } } }
  
  public var usbCables: [UsbCableId: UsbCable] {
    get { return _objectQ.sync { _usbCables } }
    set { _objectQ.sync(flags: .barrier) { _usbCables = newValue } } }
  
  public var xvtrs: [XvtrId: Xvtr] {
    get { return _objectQ.sync { _xvtrs } }
    set { _objectQ.sync(flags: .barrier) { _xvtrs = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Token enums in alphabetical order.
  // ----------------------------------------------------------------------------
  
  // ----------------------------------------------------------------------------
  // MARK: - Display tokens
  
  internal enum DisplayToken: String {
    case panadapter                         = "pan"
    case waterfall
  }
  // ----------------------------------------------------------------------------
  // MARK: - Equalizer Apf tokens
  
  internal enum EqApfToken: String {
    case gain
    case mode
    case qFactor
  }
  // ----------------------------------------------------------------------------
  // MARK: - Info reply tokens
  
  internal enum InfoToken: String {
    case atuPresent                         = "atu_present"
    case callsign
    case chassisSerial                      = "chassis_serial"
    case gateway
    case gps
    case ipAddress                          = "ip"
    case location
    case macAddress                         = "mac"
    case model
    case netmask
    case name
    case numberOfScus                       = "num_scu"
    case numberOfSlices                     = "num_slice"
    case numberOfTx                         = "num_tx"
    case options
    case region
    case screensaver
    case softwareVersion                    = "software_ver"
  }
  // ----------------------------------------------------------------------------
  // MARK: - Radio tokens
  
  internal enum RadioToken: String {
    case autoLevel                          = "auto_level"
    case backlight
    case bandPersistenceEnabled             = "band_persistence_enabled"
    case binauralRxEnabled                  = "binaural_rx"
    case calFreq                            = "cal_freq"
    case callsign
    case cw
    case CW
    case digital
    case DIGITAL
    case enforcePrivateIpEnabled            = "enforce_private_ip_connections"
    case filterSharpness                    = "filter_sharpness"
    case freqErrorPpb                       = "freq_error_ppb"
    case fullDuplexEnabled                  = "full_duplex_enabled"
    case gateway
    case headphoneGain                      = "headphone_gain"
    case headphoneMute                      = "headphone_mute"
    case ip
    case level
    case lineoutGain                        = "lineout_gain"
    case lineoutMute                        = "lineout_mute"
    case locked
    case netmask
    case nickname
    case oscillator
    case panadapters
    case pllDone                            = "pll_done"
    case remoteOnEnabled                    = "remote_on_enabled"
    case rttyMark                           = "rtty_mark_default"
    case setting
    case slices
    case snapTuneEnabled                    = "snap_tune_enabled"
    case state
    case staticNetParams                    = "static_net_params"
    case tnfEnabled                         = "tnf_enabled"
    case voice
    case VOICE
  }
  // ----------------------------------------------------------------------------
  // MARK: - Status tokens
  
  internal enum StatusToken : String {
    case amplifier
    case audioStream                        = "audio_stream"
    case atu
    case client
    case cwx
    case daxiq      // obsolete token, included to prevent log messages
    case display
    case eq
    case file
    case gps
    case interlock
    case memory
    case meter
    case micAudioStream                     = "mic_audio_stream"
    case mixer
    case opusStream                         = "opus_stream"
    case profile
    case radio
    case slice
    case stream
    case tnf
    case transmit
    case turf
    case txAudioStream                      = "tx_audio_stream"
    case usbCable                           = "usb_cable"
    case wan
    case waveform
    case xvtr
  }
  // ----------------------------------------------------------------------------
  // MARK: - Version reply tokens
  
  internal enum VersionToken: String {
    case fpgaMb                             = "fpga-mb"
    case psocMbPa100                        = "psoc-mbpa100"
    case psocMbTrx                          = "psoc-mbtrx"
    case smartSdrMB                         = "smartsdr-mb"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Radio related enums
  
  public struct FilterSpec {
    var filterHigh                          : Int
    var filterLow                           : Int
    var label                               : String
    var mode                                : String
    var txFilterHigh                        : Int
    var txFilterLow                         : Int
  }
  public struct TxFilter {
    var high                                = 0
    var low                                 = 0
  }
  
  // --------------------------------------------------------------------------------
  // MARK: - Type Alias (alphabetical)
  
  public typealias AntennaPort              = String
  public typealias FilterMode               = String
  public typealias MicrophonePort           = String
  public typealias RfGainValue              = String
}
