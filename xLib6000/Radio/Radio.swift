//
//  Radio.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

//// Radio Class implementation
///
///      as the object analog to the Radio (hardware), manages the use of all of
///      the other model objects
///
public final class Radio                    : NSObject, StaticModel, ApiDelegate {

  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kApfCmd                        = "eq apf "                     // Text of command messages
  static let kClientCmd                     = "client "
  static let kClientSetCmd                  = "client set "
  static let kCmd                           = "radio "
  static let kSetCmd                        = "radio set "
  static let kMixerCmd                      = "mixer "
  static let kUptimeCmd                     = "radio uptime"
  static let kLicenseCmd                    = "license "
  static let kXmitCmd                       = "xmit "

  // ----------------------------------------------------------------------------
  // MARK: - Public properties (Read Only)
  
  public private(set) var uptime            = 0
  @objc dynamic public var version          : String { return _api.activeRadio?.firmwareVersion ?? "" }
  @objc dynamic public var serialNumber     : String { return _api.activeRadio?.serialNumber ?? "" }

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
  private let _q                            : DispatchQueue
  private let _streamQ                      = DispatchQueue(label: Api.kId + ".streamQ", qos: .userInteractive)
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  // object collections
  private var _amplifiers                   = [AmplifierId: Amplifier]()      // Dictionary of Amplifiers
  private var _bandSettings                 = [BandId: BandSetting]()         // Dictionary of Band Settings
  private var _equalizers                   = [Equalizer.EqType: Equalizer]() // Dictionary of Equalizers
  private var _daxIqStreams                 = [StreamId: DaxIqStream]()       // Dictionary of Dax Iq streams
  private var _daxMicAudioStreams           = [StreamId: DaxMicAudioStream]() // Dictionary of MicAudio streams
  private var _daxRxAudioStreams            = [StreamId: DaxRxAudioStream]()  // Dictionary of Audio streams
  private var _daxTxAudioStreams            = [StreamId: DaxTxAudioStream]()  // Dictionary of Tx Audio streams
  private var _memories                     = [MemoryId: Memory]()            // Dictionary of Memories
  private var _meters                       = [MeterNumber: Meter]()          // Dictionary of Meters
  private var _opusStreams                  = [OpusId: Opus]()                // Dictionary of Opus Streams
  private var _panadapters                  = [PanadapterId: Panadapter]()    // Dictionary of Panadapters
  private var _profiles                     = [ProfileId: Profile]()          // Dictionary of Profiles
  private var _replyHandlers                = [SequenceId: ReplyTuple]()      // Dictionary of pending replies
  private var _slices                       = [SliceId: Slice]()              // Dictionary of Slices
  private var _tnfs                         = [TnfId: Tnf]()                  // Dictionary of Tnfs
  private var _usbCables                    = [UsbCableId: UsbCable]()        // Dictionary of UsbCables
  private var _waterfalls                   = [WaterfallId: Waterfall]()      // Dictionary of Waterfalls
  private var _xvtrs                        = [XvtrId: Xvtr]()                // Dictionary of Xvtrs
  
  private var _gpsPresent                   = false
  private var _atuPresent                   = false
  private var _clientInitialized            = false
  
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
  private var __boundClientId               : UUID?                         // The Client Id of this client's GUI
  private var __clientIp                    = ""                            // Ip address returned by "client ip" command
  // D
  private var __daxIqAvailable              = 0                             //
  private var __daxIqCapacity               = 0                             //
  // E
  private var __enforcePrivateIpEnabled     = false                         //
  private var __extPresent                  = false                         //
  // F
  private var __filterCwAutoEnabled         = false                         //
  private var __filterCwLevel               = 0                             //
  private var __filterDigitalAutoEnabled    = false                         //
  private var __filterDigitalLevel          = 0                             //
  private var __filterVoiceAutoEnabled      = false                         //
  private var __filterVoiceLevel            = 0                             //
  private var __fpgaMbVersion               = ""                            // FPGA version (read only)
  private var __freqErrorPpb                = 0                             // Calibration error (Hz)
  private var __frontSpeakerMute            = false                         //
  private var __fullDuplexEnabled           = false                         // Full duplex enable
  // G
  private var __gateway                     = ""                            // (read only)
  private var __gpsdoPresent                = false                         //
  // H
  private var __headphoneGain               = 0                             // Headset gain (1-100)
  private var __headphoneMute               = false                         // Headset muted
  // I
  private var __ipAddress                   = ""                            // IP Address (dotted decimal) (read only)
  // L
  private var __lineoutGain                 = 0                             // Speaker gain (1-100)
  private var __lineoutMute                 = false                         // Speaker muted
  private var __localPtt                    = false                         // PTT usage
  private var __location                    = ""                            // (read only)
  private var __locked                      = false                         //
  // M
  private var __macAddress                  = ""                            // Radio Mac Address (read only)
  private var __mox                         = false                         // manual Transmit
  private var __muteLocalAudio              = false                         // mute local audio when remote
  // N
  private var __netmask                     = ""                            //
  private var __nickname                    = ""                            // User assigned name
  private var __numberOfScus                = 0                             // NUmber of SCU's (read only)
  private var __numberOfSlices              = 0                             // Number of Slices (read only)
  private var __numberOfTx                  = 0                             // Number of TX (read only)
  // O
  private var __oscillator                  = ""                            //
  // P
  private var __picDecpuVersion             = ""                            // 
  private var __program                     = ""                            // Client program
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
  private var __startCalibration            = false                         // true if a Calibration is in progress
  private var __state                       = ""                            //
  private var __station                     = ""                            // Station name
  private var __staticGateway               = ""                            // Static Gateway address
  private var __staticIp                    = ""                            // Static IpAddress
  private var __staticNetmask               = ""                            // Static Netmask
  // T
  private var __tcxoPresent                 = false                         //
  private var __tnfsEnabled                 = false                         // TNF's enable
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Radio Class
  ///
  /// - Parameters:
  ///   - api:        an Api instance
  ///
  public init(api: Api, queue: DispatchQueue) {
    
    _api = api
    _q = queue

    super.init()

    _api.delegate = self
    
    // initialize the static models (only one of each is ever created)
    atu = Atu(queue: _q)
    cwx = Cwx(queue: _q)
    gps = Gps(queue: _q)
    interlock = Interlock(queue: _q)
    transmit = Transmit(queue: _q)
    wan = Wan(queue: _q)
    waveform = Waveform(queue: _q)
    
    // initialize Equalizers (use the newer "sc" type)
    equalizers[.rxsc] = Equalizer(id: Equalizer.EqType.rxsc.rawValue, queue: _q)
    equalizers[.txsc] = Equalizer(id: Equalizer.EqType.txsc.rawValue, queue: _q)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Remove all Radio objects
  ///
  public func removeAll() {
    
    // ----- remove all objects -----
    //      NOTE: order is important
    
    // notify all observers, then remove
    daxIqStreams.forEach( { NC.post(.daxIqStreamWillBeRemoved, object: $0.value as Any?) } )
    daxIqStreams.removeAll()
    
    daxMicAudioStreams.forEach( {NC.post(.daxMicAudioStreamWillBeRemoved, object: $0.value as Any?)} )
    daxMicAudioStreams.removeAll()
    
    daxRxAudioStreams.forEach( { NC.post(.daxRxAudioStreamWillBeRemoved, object: $0.value as Any?) } )
    daxRxAudioStreams.removeAll()

    daxTxAudioStreams.forEach( { NC.post(.daxTxAudioStreamWillBeRemoved, object: $0.value as Any?) } )
    daxTxAudioStreams.removeAll()
    
    opusStreams.forEach( { NC.post(.opusRxWillBeRemoved, object: $0.value as Any?) } )
    opusStreams.removeAll()
    
    tnfs.forEach( { NC.post(.tnfWillBeRemoved, object: $0.value as Any?) } )
    tnfs.removeAll()
    
    slices.forEach( { NC.post(.sliceWillBeRemoved, object: $0.value as Any?) } )
    slices.removeAll()
    
    panadapters.forEach( {
      
      let waterfallId = $0.value.waterfallId
      let waterfall = waterfalls[waterfallId]
      
      // notify all observers
      NC.post(.panadapterWillBeRemoved, object: $0.value as Any?)
      
      NC.post(.waterfallWillBeRemoved, object: waterfall as Any?)
    })
    panadapters.removeAll()
    waterfalls.removeAll()
    
    profiles.forEach( {
      NC.post(.profileWillBeRemoved, object: $0.value.list as Any?)
      $0.value._list.removeAll()
    } )

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
    
    _clientInitialized = false
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Change the MOX property when an Interlock state change occurs
  ///
  /// - Parameter state:            a new Interloack state
  ///
  internal func stateChange(_ state: String) {
    
    let currentMox = _mox
    
    // if PTT_REQUESTED or TRANSMITTING
    if state == Interlock.State.pttRequested.rawValue || state == Interlock.State.transmitting.rawValue {
      
      // if mox not on, turn it on
      if currentMox == false {
        willChangeValue(for: \.mox)
        _mox = true
        didChangeValue(for: \.mox)
      }
      
      // if READY or UNKEY_REQUESTED
    } else if state == Interlock.State.ready.rawValue || state == Interlock.State.unKeyRequested.rawValue {
      
      // if mox is on, turn it off
      if currentMox == true {
        willChangeValue(for: \.mox)
        _mox = false
        didChangeValue(for: \.mox)
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Parse a Message. format: <messageNumber>|<messageText>
  ///
  ///   executed on the parseQ
  ///
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  ///
  private func parseMessage(_ commandSuffix: String) {
    
    // separate it into its components
    let components = commandSuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted messages
    if components.count < 2 {
      
//      os_log("Incomplete message, c%{public}@", log: _log, type: .default, commandSuffix)
      _api.log.msg( "Incomplete message, \(commandSuffix))", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    // bits 24-25 are the errorCode???
//    let msgNumber = UInt32(components[0]) ?? 0
//    let errorCode = Int((msgNumber & 0x03000000) >> 24)
    let msgText = components[1]
    
    // FIXME: use errorCode properly
    
    // log it
//    os_log("%{public}@", log: _log, type: .default, msgText)
    _api.log.msg( msgText, level: .warning, function: #function, file: #file, line: #line)

    // FIXME: Take action on some/all errors?
  }
  /// Parse a Reply. format: <sequenceNumber>|<hexResponse>|<message>[|<debugOutput>]
  ///
  ///   executed on the parseQ
  ///
  /// - Parameters:
  ///   - commandSuffix:      a Reply Suffix
  ///
  private func parseReply(_ replySuffix: String) {
    
    // separate it into its components
    let components = replySuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted replies
    if components.count < 2 {
//      os_log("Incomplete reply, r%{public}@", log: _log, type: .default, replySuffix)
      _api.log.msg( "Incomplete reply, \(replySuffix)", level: .warning, function: #function, file: #file, line: #line)
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
        defaultReplyHandler(replyTuple.command, seqNum: components[0], responseValue: components[1], reply: replySuffix)
      }
      // Remove the object from the notification list
      replyHandlers[components[0]] = nil
      
    } else {
      
      // no Object is waiting for this reply, log it if it is a non-zero Reply (i.e a possible error)
      if components[1] != Api.kNoError {

//        os_log("Unhandled non-zero reply, c%{public}@, r%{public}@, %{public}@", log: _log, type: .default, components[0], replySuffix, flexErrorString(errorCode: components[1]))
        _api.log.msg( "Unhandled non-zero reply, \(components[0]), \(replySuffix), \(flexErrorString(errorCode: components[1]))", level: .warning, function: #function, file: #file, line: #line)
      }
    }
  }
  /// Parse a Status. format: <apiHandle>|<message>, where <message> is of the form: <msgType> <otherMessageComponents>
  ///
  ///   executed on the parseQ
  ///
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  ///
  private func parseStatus(_ commandSuffix: String) {
    
    // separate it into its components ( [0] = <apiHandle>, [1] = <remainder> )
    var components = commandSuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted status
    guard components.count > 1 else {
      
//      os_log("Incomplete status, c%{public}@", log: _log, type: .default, commandSuffix)
      _api.log.msg( "Incomplete status, \(commandSuffix)", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    // find the space & get the msgType
    let spaceIndex = components[1].firstIndex(of: " ")!
    let msgType = String(components[1][..<spaceIndex])
    
    // everything past the msgType is in the remainder
    let remainderIndex = components[1].index(after: spaceIndex)
    let remainder = String(components[1][remainderIndex...])
    
    // Check for unknown Message Types
    guard let token = StatusToken(rawValue: msgType)  else {
      
      // unknown Message Type, log it and ignore the message
//      os_log("Unknown Status token - %{public}@", log: _log, type: .default, msgType)
      _api.log.msg( "Unknown Status token - \(msgType)", level: .warning, function: #function, file: #file, line: #line)

      return
    }
    
    
    // FIXME: ***** file, mixer & turf Not currently implemented *****
    
    
    // Known Message Types, in alphabetical order
    switch token {
      
    case .amplifier:
      // FIXME: Need format(s)
      Amplifier.parseStatus(remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kRemoved))
      
//    case .audioStream:
//      //      format: <AudioStreamId> <key=value> <key=value> ...<key=value>
//      DaxRxAudioStream.parseStatus(remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kNotInUse))
      
    case .atu:
      //      format: <key=value> <key=value> ...<key=value>
      atu.parseProperties( remainder.keyValuesArray() )
      
    case .client:
      //      kv                0         1            2
      //      format: client <handle> connected <client_id=ID> <program=Program> <station=Station> <local_ptt=0/1>
      //      format: client <handle> disconnected <forced=0/1>

//      Swift.print("Client status: \(remainder)")

      let keyValues = remainder.keyValuesArray()
      GuiClient.parseStatus(keyValues, radio: self, queue: _q)

      // is my Client initialized now?
      if keyValues[0].key.handle != 0 {
        
        if _api.guiClients[keyValues[0].key.handle] != nil && !_clientInitialized {
          // YES
          _clientInitialized = true
          
          // Finish the UDP initialization & set the API state
          _api.clientConnected()
        }
      }

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
        Panadapter.parseStatus(keyValues, radio: self, queue: _q, inUse: !remainder.contains(Api.kRemoved))
        
      case DisplayToken.waterfall.rawValue:
        Waterfall.parseStatus(keyValues, radio: self, queue: _q, inUse: !remainder.contains(Api.kRemoved))
        
      default:
        // unknown Display Type, log it and ignore the message
//        os_log("Unknown Display - %{public}@", log: _log, type: .default, keyValues[0].key)
        _api.log.msg( "Unknown Display - \(keyValues[0].key)", level: .warning, function: #function, file: #file, line: #line)
      }
      
    case .eq:
      //      format: txsc <key=value> <key=value> ...<key=value>
      //      format: rxsc <key=value> <key=value> ...<key=value>
      Equalizer.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q )
      
    case .file:
//      os_log("Unprocessed %{public}@, %{public}@", log: _log, type: .default, msgType, remainder)
      _api.log.msg( "Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)

    case .gps:
      //     format: <key=value>#<key=value>#...<key=value>
      gps.parseProperties( remainder.keyValuesArray(delimiter: "#") )
      
    case .interlock:
      //      format: <key=value> <key=value> ...<key=value>
      
      var keyValues = remainder.keyValuesArray()
      
      // is it a Band Setting?
      if keyValues[0].key == "band" {
        // YES, drop the "band"
        keyValues = Array(keyValues.dropFirst())
        BandSetting.parseStatus( keyValues, radio: self, queue: _q, inUse: true)
      } else {
        // NO, standard Interlock
        interlock.parseProperties( keyValues)
      }
      
    case .memory:
      //      format: <memoryId> <key=value>,<key=value>,...<key=value>
      Memory.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kRemoved))
      
    case .meter:
      //     format: <meterNumber.key=value>#<meterNumber.key=value>#...<meterNumber.key=value>
      Meter.parseStatus( remainder.keyValuesArray(delimiter: "#"), radio: self, queue: _q, inUse: !remainder.contains(Api.kRemoved))
      
//    case .micAudioStream:
//      //      format: <MicAudioStreamId> <key=value> <key=value> ...<key=value>
//      DaxMicAudioStream.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kNotInUse))
      
    case .mixer:
//      os_log("Unprocessed %{public}@, %{public}@", log: _log, type: .default, msgType, remainder)
      _api.log.msg( "Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)

    case .opusStream:
      //     format: <opusId> <key=value> <key=value> ...<key=value>
      Opus.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q)
      
    case .profile:
      //     format: global list=<value>^<value>^...<value>^
      //     format: global current=<value>
      //     format: tx list=<value>^<value>^...<value>^
      //     format: tx current=<value>
      //     format: mic list=<value>^<value>^...<value>^
      //     format: mic current=<value>
      Profile.parseStatus( remainder.keyValuesArray(delimiter: "="), radio: self, queue: _q)
      
    case .radio:
      //     format: <key=value> <key=value> ...<key=value>
      parseProperties( remainder.keyValuesArray())
      
    case .slice:
      //     format: <sliceId> <key=value> <key=value> ...<key=value>
      xLib6000.Slice.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kNotInUse))
      
    case .stream:
      //     format: <streamId, > <key=value> <key=value> ...<key=value>
      //     format: <streamId, > <"removed",>
      var keyValues = remainder.keyValuesArray()
      
      // ignore the removed status message
      if keyValues[2].key == "removed" { return }
      
      switch keyValues[1].value {
      case "dax_iq":
        //     format: <streamId, > <"type"=value> <"dax_channel"=value> <"pan"=value> <"daxiq_rate"=value> <"client_handle"=value> <"active"=1/0>
        DaxIqStream.parseStatus( keyValues, radio: self, queue: _q)
      case "dax_mic":
        //     format: <streamId, > <"type"=value> <"client_handle"=value>
        DaxMicAudioStream.parseStatus( keyValues, radio: self, queue: _q)
      case "dax_rx":
        //     format: <streamId, > <"type"=value> <"dax_channel"=value> <"slice"=value> <"dax_clients"=value> <"client_handle"=value>
        DaxRxAudioStream.parseStatus( keyValues, radio: self, queue: _q)
      case "dax_tx":
        //     format: <streamId, > <"type"=value> <"client_handle"=value> <"dax_tx"=value>
        DaxTxAudioStream.parseStatus( keyValues, radio: self, queue: _q)
      default:
        fatalError()
      }
      
    case .tnf:
      //     format: <tnfId> <key=value> <key=value> ...<key=value>
      Tnf.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kRemoved))
      
    case .transmit:
      //      format: <key=value> <key=value> ...<key=value>
      var keyValues = remainder.keyValuesArray()
      
      // is it a Band Setting?
      if keyValues[0].key == "band" {
        // YES, drop the "band"
        keyValues = Array(keyValues.dropFirst())
        BandSetting.parseStatus( keyValues, radio: self, queue: _q, inUse: !remainder.contains(Api.kRemoved))
      } else {
        // NO, standard Transmit
        transmit.parseProperties( keyValues)
      }
      
    case .turf:
//      os_log("Unprocessed %{public}@, %{public}@", log: _log, type: .default, msgType, remainder)
      _api.log.msg( "Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)

//    case .txAudioStream:
//      //      format: <TxAudioStreamId> <key=value> <key=value> ...<key=value>
//      DaxTxAudioStream.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kNotInUse))
      
    case .usbCable:
      //      format:
      UsbCable.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q)
      
    case .wan:
      wan.parseProperties( remainder.keyValuesArray() )
      
    case .waveform:
      //      format: <key=value> <key=value> ...<key=value>
      waveform.parseProperties( remainder.keyValuesArray())
      
    case .xvtr:
      //      format: <name> <key=value> <key=value> ...<key=value>
      Xvtr.parseStatus( remainder.keyValuesArray(), radio: self, queue: _q, inUse: !remainder.contains(Api.kNotInUse))
    }
  }
  /// Parse the Reply to an Info command, reply format: <key=value> <key=value> ...<key=value>
  ///
  ///   executed on the parseQ
  ///
  /// - Parameters:
  ///   - properties:          a KeyValuesArray
  ///
  private func parseInfoReply(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Keys
      guard let token = InfoToken(rawValue: property.key) else {
        // log it and ignore this Key
//        os_log("Unknown Info token - %{public}@ = %{public}@", log: _log, type: .default, property.key, property.value)
        _api.log.msg( "Unknown Info token - \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .atuPresent:
        willChangeValue(for: \.atuPresent)
        _atuPresent = property.value.bValue
        didChangeValue(for: \.atuPresent)

      case .callsign:
        willChangeValue(for: \.callsign)
        _callsign = property.value
        didChangeValue(for: \.callsign)

      case .chassisSerial:
        willChangeValue(for: \.chassisSerial)
        _chassisSerial = property.value
        didChangeValue(for: \.chassisSerial)

      case .gateway:
        willChangeValue(for: \.gateway)
        _gateway = property.value
        didChangeValue(for: \.gateway)

      case .gps:
        willChangeValue(for: \.gpsPresent)
        _gpsPresent = (property.value != "Not Present")
        didChangeValue(for: \.gpsPresent)

      case .ipAddress:
        willChangeValue(for: \.ipAddress)
        _ipAddress = property.value
        didChangeValue(for: \.ipAddress)

      case .location:
        willChangeValue(for: \.location)
        _location = property.value
        didChangeValue(for: \.location)

      case .macAddress:
        willChangeValue(for: \.macAddress)
        _macAddress = property.value
        didChangeValue(for: \.macAddress)

      case .model:
         willChangeValue(for: \.radioModel)
         _radioModel = property.value
         didChangeValue(for: \.radioModel)

      case .netmask:
        willChangeValue(for: \.netmask)
        _netmask = property.value
        didChangeValue(for: \.netmask)

      case .name:
        willChangeValue(for: \.nickname)
        _nickname = property.value
        didChangeValue(for: \.nickname)

      case .numberOfScus:
        willChangeValue(for: \.numberOfScus)
        _numberOfScus = property.value.iValue
        didChangeValue(for: \.numberOfScus)

      case .numberOfSlices:
        willChangeValue(for: \.numberOfSlices)
        _numberOfSlices = property.value.iValue
        didChangeValue(for: \.numberOfSlices)

      case .numberOfTx:
        willChangeValue(for: \.numberOfTx)
        _numberOfTx = property.value.iValue
        didChangeValue(for: \.numberOfTx)

      case .options:
        willChangeValue(for: \.radioOptions)
        _radioOptions = property.value
        didChangeValue(for: \.radioOptions)

      case .region:
        willChangeValue(for: \.region)
        _region = property.value
        didChangeValue(for: \.region)

      case .screensaver:
        willChangeValue(for: \.radioScreenSaver)
        _radioScreenSaver = property.value
        didChangeValue(for: \.radioScreenSaver)

      case .softwareVersion:
        willChangeValue(for: \.softwareVersion)
        _softwareVersion = property.value
        didChangeValue(for: \.softwareVersion)
      }
    }
  }
  /// Parse the Reply to a Client Gui command, reply format: <key=value> <key=value> ...<key=value>
  ///
  ///   executed on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray
  ///
  private func parseGuiReply(_ properties: KeyValuesArray) {
    
    // only v3 returns a Client Id
    for property in properties {
      // save the returned ID
      _boundClientId = UUID(uuidString: property.key)
      break
    }
    
  }
  /// Parse the Reply to a Client Ip command, reply format: <key=value> <key=value> ...<key=value>
  ///
  ///   executed on the parseQ
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
  ///   executed on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray
  ///
  private func parseVersionReply(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Tokens
      guard let token = VersionToken(rawValue: property.key) else {
        // log it and ignore this Token
//        os_log("Unknown Version token - %{public}@ = %{public}@", log: _log, type: .default, property.key, property.value)
        _api.log.msg( "Unknown Version token - \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .smartSdrMB:
        willChangeValue(for: \.smartSdrMB)
        _smartSdrMB = property.value
        didChangeValue(for: \.smartSdrMB)

      case .picDecpu:
        willChangeValue(for: \.picDecpuVersion)
        _picDecpuVersion = property.value
        didChangeValue(for: \.picDecpuVersion)

      case .psocMbTrx:
        willChangeValue(for: \.psocMbtrxVersion)
        _psocMbtrxVersion = property.value
        didChangeValue(for: \.psocMbtrxVersion)

      case .psocMbPa100:
        willChangeValue(for: \.psocMbPa100Version)
        _psocMbPa100Version = property.value
        didChangeValue(for: \.psocMbPa100Version)

      case .fpgaMb:
        willChangeValue(for: \.fpgaMbVersion)
        _fpgaMbVersion = property.value
        didChangeValue(for: \.fpgaMbVersion)
      }
    }
  }
  
  // --------------------------------------------------------------------------------
  // MARK: - Protocol instance methods
  
  /// Parse a Radio status message
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // FIXME: What about a 6700 with two scu's?
    
    // separate by category
    if let category = RadioTokenCategory(rawValue: properties[0].key) {
      
      // drop the first property
      let adjustedProperties = Array(properties[1...])
      
      switch category {
        
      case .filterSharpness:
        parseFilterProperties( adjustedProperties )
        
      case .staticNetParams:
        parseStaticNetProperties( adjustedProperties )
        
      case .oscillator:
        parseOscillatorProperties( adjustedProperties )
      }
      
    } else {
    
      // process each key/value pair, <key=value>
      for property in properties {
        
        // Check for Unknown token
        guard let token = RadioToken(rawValue: property.key)  else {
          
          // log it and ignore this token
//          os_log("Unknown Radio token - %{public}@ = %{public}@", log: _log, type: .default, property.key, property.value)
          _api.log.msg( "Unknown Radio token - \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
          continue
        }
        // Known tokens, in alphabetical order
        switch token {
          
        case .backlight:
          willChangeValue(for: \.backlight)
          _backlight = property.value.iValue
          didChangeValue(for: \.backlight)

        case .bandPersistenceEnabled:
          willChangeValue(for: \.bandPersistenceEnabled)
          _bandPersistenceEnabled = property.value.bValue
          didChangeValue(for: \.bandPersistenceEnabled)

        case .binauralRxEnabled:
          willChangeValue(for: \.binauralRxEnabled)
          _binauralRxEnabled = property.value.bValue
          didChangeValue(for: \.binauralRxEnabled)

        case .calFreq:
          willChangeValue(for: \.calFreq)
          _calFreq = property.value.mhzToHz
          didChangeValue(for: \.calFreq)

        case .callsign:
          willChangeValue(for: \.callsign)
          _callsign = property.value
          didChangeValue(for: \.callsign)

        case .daxIqAvailable:
          willChangeValue(for: \.daxIqAvailable)
          _daxIqAvailable = property.value.iValue
          didChangeValue(for: \.daxIqAvailable)
          
        case .daxIqCapacity:
          willChangeValue(for: \.daxIqCapacity)
          _daxIqCapacity = property.value.iValue
          didChangeValue(for: \.daxIqCapacity)
          
        case .enforcePrivateIpEnabled:
          willChangeValue(for: \.enforcePrivateIpEnabled)
          _enforcePrivateIpEnabled = property.value.bValue
          didChangeValue(for: \.enforcePrivateIpEnabled)

        case .freqErrorPpb:
          willChangeValue(for: \.freqErrorPpb)
          _freqErrorPpb = property.value.iValue
          didChangeValue(for: \.freqErrorPpb)

        case .fullDuplexEnabled:
          willChangeValue(for: \.fullDuplexEnabled)
          _fullDuplexEnabled = property.value.bValue
          didChangeValue(for: \.fullDuplexEnabled)

        case .frontSpeakerMute:
          willChangeValue(for: \.frontSpeakerMute)
          _frontSpeakerMute = property.value.bValue
          didChangeValue(for: \.frontSpeakerMute)

        case .headphoneGain:
          willChangeValue(for: \.headphoneGain)
          _headphoneGain = property.value.iValue
          didChangeValue(for: \.headphoneGain)

        case .headphoneMute:
          willChangeValue(for: \.headphoneMute)
          _headphoneMute = property.value.bValue
          didChangeValue(for: \.headphoneMute)

        case .lineoutGain:
          willChangeValue(for: \.lineoutGain)
          _lineoutGain = property.value.iValue
          didChangeValue(for: \.lineoutGain)

        case .lineoutMute:
          willChangeValue(for: \.lineoutMute)
          _lineoutMute = property.value.bValue
          didChangeValue(for: \.lineoutMute)
          
        case .muteLocalAudio:
          willChangeValue(for: \.muteLocalAudio)
          _muteLocalAudio = property.value.bValue
          didChangeValue(for: \.muteLocalAudio)

        case .nickname:
          willChangeValue(for: \.nickname)
          _nickname = property.value
          didChangeValue(for: \.nickname)

        case .panadapters:
          willChangeValue(for: \.availablePanadapters)
          _availablePanadapters = property.value.iValue
          didChangeValue(for: \.availablePanadapters)

        case .pllDone:
          willChangeValue(for: \.startCalibration)
          _startCalibration = !(property.value.bValue)
          didChangeValue(for: \.startCalibration)

        case .remoteOnEnabled:
          willChangeValue(for: \.remoteOnEnabled)
          _remoteOnEnabled = property.value.bValue
          didChangeValue(for: \.remoteOnEnabled)

        case .rttyMark:
          willChangeValue(for: \.rttyMark)
          _rttyMark = property.value.iValue
          didChangeValue(for: \.rttyMark)

        case .slices:
          willChangeValue(for: \.availableSlices)
          _availableSlices = property.value.iValue
          didChangeValue(for: \.availableSlices)

        case .snapTuneEnabled:
          willChangeValue(for: \.snapTuneEnabled)
          _snapTuneEnabled = property.value.bValue
          didChangeValue(for: \.snapTuneEnabled)

        case .tnfsEnabled:
          willChangeValue(for: \.tnfsEnabled)
          _tnfsEnabled = property.value.bValue
          didChangeValue(for: \.tnfsEnabled)
        }
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
  /// Parse a Filter Properties status message
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  ///
  private func parseFilterProperties(_ properties: KeyValuesArray) {
    var cw = false
    var digital = false
    var voice = false

    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = RadioFilterSharpness(rawValue: property.key)  else {
        
        // log it and ignore this token
//        os_log("Unknown Filter token - %{public}@ = %{public}@", log: _log, type: .default, property.key, property.value)
        _api.log.msg( "Unknown Filter token - \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .autoLevel:
        if cw {
          willChangeValue(for: \.filterCwAutoEnabled)
          _filterCwAutoEnabled = property.value.bValue
          didChangeValue(for: \.filterCwAutoEnabled)
          cw = false
        }
        if digital {
          willChangeValue(for: \.filterDigitalAutoEnabled)
          _filterDigitalAutoEnabled = property.value.bValue
          didChangeValue(for: \.filterDigitalAutoEnabled)
          digital = false
        }
        if voice {
          willChangeValue(for: \.filterVoiceAutoEnabled)
          _filterVoiceAutoEnabled = property.value.bValue
          didChangeValue(for: \.filterVoiceAutoEnabled)
          voice = false
        }
        
      case .cw, .CW:
        cw = true
        
      case .digital, .DIGITAL:
        digital = true
        
      case .level:
        if cw {
          willChangeValue(for: \.filterCwLevel)
          _filterCwLevel = property.value.iValue
          didChangeValue(for: \.filterCwLevel)
        }
        if digital {
          willChangeValue(for: \.filterDigitalLevel)
          _filterDigitalLevel = property.value.iValue
          didChangeValue(for: \.filterDigitalLevel)
        }
        if voice {
          willChangeValue(for: \.filterVoiceLevel)
          _filterVoiceLevel = property.value.iValue
          didChangeValue(for: \.filterVoiceLevel)
        }
        
      case .voice, .VOICE:
        voice = true
      }
    }
  }
  /// Parse a Static Net Properties status message
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  ///
  private func parseStaticNetProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = RadioStaticNet(rawValue: property.key)  else {
        
        // log it and ignore this token
//        os_log("Unknown Static token - %{public}@ = %{public}@", log: _log, type: .default, property.key, property.value)
        _api.log.msg( "Unknown Static token - \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .gateway:
        willChangeValue(for: \.staticGateway)
        _staticGateway = property.value
        didChangeValue(for: \.staticGateway)

      case .ip:
        willChangeValue(for: \.staticIp)
        _staticIp = property.value
        didChangeValue(for: \.staticIp)

      case .netmask:
        willChangeValue(for: \.staticNetmask)
        _staticNetmask = property.value
        didChangeValue(for: \.staticNetmask)
      }
    }
  }
  /// Parse an Oscillator Properties status message
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  ///
  private func parseOscillatorProperties(_ properties: KeyValuesArray) {
      
      // process each key/value pair, <key=value>
      for property in properties {
        
        // Check for Unknown token
        guard let token = RadioOscillator(rawValue: property.key)  else {
          
          // log it and ignore this token
//          os_log("Unknown Oscillator token - %{public}@ = %{public}@", log: _log, type: .default, property.key, property.value)
          _api.log.msg( "Unknown Oscillator token - \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)

          continue
        }
        // Known tokens, in alphabetical order
        switch token {
          
        case .extPresent:
          willChangeValue(for: \.extPresent)
          _extPresent = property.value.bValue
          didChangeValue(for: \.extPresent)

        case .gpsdoPresent:
          willChangeValue(for: \.gpsdoPresent)
          _gpsdoPresent = property.value.bValue
          didChangeValue(for: \.gpsdoPresent)

       case .locked:
          willChangeValue(for: \.locked)
          _locked = property.value.bValue
          didChangeValue(for: \.locked)

        case .setting:
          willChangeValue(for: \.setting)
          _setting = property.value
          didChangeValue(for: \.setting)

        case .state:
          willChangeValue(for: \.state)
          _state = property.value
          didChangeValue(for: \.state)

        case .tcxoPresent:
          willChangeValue(for: \.tcxoPresent)
          _tcxoPresent = property.value.bValue
          didChangeValue(for: \.tcxoPresent)
        }
      }
    }
  
  // ----------------------------------------------------------------------------
  // MARK: - Api delegate methods
  
  /// Parse inbound Tcp messages
  ///
  ///   executes on the parseQ
  ///
  /// - Parameter msg:        the Message String
  ///
  public func receivedMessage(_ msg: String) {
    
    // get all except the first character
    let suffix = String(msg.dropFirst())
    
    // switch on the first character
    switch msg[msg.startIndex] {
      
    case "H", "h":   // Handle type
      _api.connectionHandle = suffix.handle
      
    case "M", "m":   // Message Type
      parseMessage(suffix)
      
    case "R", "r":   // Reply Type
      parseReply(suffix)
      
    case "S", "s":   // Status type
      parseStatus(suffix)
      
    case "V", "v":   // Version Type
      _hardwareVersion = suffix
      
    default:    // Unknown Type
//      os_log("Unexpected message -  %{public}@", log: _log, type: .default, msg)
      _api.log.msg( "Unexpected message -  \(msg)", level: .warning, function: #function, file: #file, line: #line)
    }
  }
  /// Process outbound Tcp messages
  ///
  /// - Parameter msg:    the Message text
  ///
  public func sentMessage(_ text: String) {
    // unused in xLib6000
  }
  /// Add a Reply Handler for a specific Sequence/Command
  ///
  ///   executes on the parseQ
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
  ///   executes on the parseQ
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
        let errorLevel = flexErrorLevel(errorCode: responseValue)
//        let errorType = (errorLevel == "Error" || errorLevel == "Fatal" || errorLevel == "Unknown error" ? OSLogType.default : OSLogType.info)
//        os_log("c%{public}@, %{public}@, non-zero reply %{public}@, %{public}@ (%{public}@)", log: _log, type: errorType, seqNum, command, responseValue, flexErrorString(errorCode: responseValue), errorLevel)
        _api.log.msg( "c\(seqNum), \(command), non-zero reply \(responseValue), \(flexErrorString(errorCode: responseValue)) (\(errorLevel))", level: .warning, function: #function, file: #file, line: #line)

        // FIXME: ***** Temporarily commented out until bugs in v2.4.9 are fixed *****
        
//        switch errorLevel {
//
//        case "Error", "Fatal error", "Unknown error":
//          DispatchQueue.main.sync {
//            let alert = NSAlert()
//            alert.messageText = "\(errorLevel) on command\nc\(seqNum)|\(command)"
//            alert.informativeText = "\(responseValue) \n\(flexErrorString(errorCode: responseValue)) \n\nAPPLICATION WILL BE TERMINATED"
//            alert.alertStyle = .critical
//            alert.addButton(withTitle: "Ok")
//
//            let _ = alert.runModal()
//
//            // terminate App
//            NSApp.terminate(self)
//          }
//
//        default:
//          break
//        }
      }
      return
    }

    // which command?
    switch command {
      
    case Api.Command.clientGui.rawValue:
      // process the reply
      parseGuiReply( reply.keyValuesArray() )
      
    case Api.Command.clientIp.rawValue:
      // process the reply
      parseIpReply( reply.keyValuesArray() )
      
    case Api.Command.info.rawValue:
      // process the reply
      parseInfoReply( (reply.replacingOccurrences(of: "\"", with: "")).keyValuesArray(delimiter: ",") )
      
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
        
//      } else if command.hasPrefix(DaxRxAudioStream.kStreamCreateCmd + "dax=") {
//
//        // TODO: add code
//        break
//
//      } else if command.hasPrefix(DaxRxAudioStream.kStreamCreateCmd + "daxmic") {
//
//        // TODO: add code
//        break
//
//      } else if command.hasPrefix(DaxRxAudioStream.kStreamCreateCmd + "daxtx") {
//
//        // TODO: add code
//        break
//
//      } else if command.hasPrefix(DaxIqStream.kStreamCreateCmd + "daxiq") {
//
//        // TODO: add code
//        break
//
      } else if command.hasPrefix(xLib6000.Slice.kCmd + "get_error"){
        
        // save the errors, format: <rx_error_value>,<tx_error_value>
        sliceErrors = reply.valuesArray( delimiter: "," )
      }
    }
  }
  /// Process received UDP Vita packets
  ///
  ///   arrives on the udpReceiveQ, calls targets on the streamQ
  ///
  /// - Parameter vitaPacket:       a Vita packet
  ///
  public func vitaParser(_ vitaPacket: Vita) {
    
    _streamQ.async { [unowned self ] in
      
      // Pass the stream to the appropriate object (checking for existence of the object first)
      switch (vitaPacket.classCode) {
        
      case .daxAudio:
        // Dax Microphone Audio
        if let daxAudio = self.daxRxAudioStreams[vitaPacket.streamId] {
          daxAudio.vitaProcessor(vitaPacket)
        }
        // Dax Slice Audio
        if let daxMicAudio = self.daxMicAudioStreams[vitaPacket.streamId] {
          daxMicAudio.vitaProcessor(vitaPacket)
        }

      case .daxIq24, .daxIq48, .daxIq96, .daxIq192:
        // Dax IQ
        if let daxIq = self.daxIqStreams[vitaPacket.streamId] {

          daxIq.vitaProcessor(vitaPacket)
        }
        
      case .meter:
        // Meter - unlike other streams, the Meter stream contains multiple Meters
        //         and must be processed by a class method on the Meter object
        Meter.vitaProcessor(vitaPacket)
        
      case .opus:
        // Opus
        if let opus = self.opusStreams[vitaPacket.streamId] {

          if opus.isStreaming == false {
            opus.isStreaming = true
            // log the start of the stream
//            os_log("Opus Stream started: ID = %{public}@ ", log: self._log, type: .info, vitaPacket.streamId.hex)
            self._api.log.msg( "Opus Stream started: ID = \(vitaPacket.streamId.hex)", level: .info, function: #function, file: #file, line: #line)
          }
          opus.vitaProcessor( vitaPacket )
        }
        
      case .panadapter:
        // Panadapter
        if let panadapter = self.panadapters[vitaPacket.streamId] {
          
          if panadapter.isStreaming == false {
            panadapter.isStreaming = true
            // log the start of the stream
//            os_log("Panadapter Stream started: ID = %{public}@ ", log: self._log, type: .info, vitaPacket.streamId.hex)
            self._api.log.msg( "Panadapter Stream started: ID = \(vitaPacket.streamId.hex)", level: .info, function: #function, file: #file, line: #line)
          }
          panadapter.vitaProcessor(vitaPacket)
        }
        
      case .waterfall:
        // Waterfall
        if let waterfall = self.waterfalls[vitaPacket.streamId] {
          
          if waterfall.isStreaming == false {
            waterfall.isStreaming = true
            // log the start of the stream
//            os_log("Waterfall Stream started: ID = %{public}@ ", log: self._log, type: .info, vitaPacket.streamId.hex)
            self._api.log.msg( "Waterfall Stream started: ID = \(vitaPacket.streamId.hex)", level: .info, function: #function, file: #file, line: #line)
          }
          waterfall.vitaProcessor(vitaPacket)
        }
        
      default:
        // log the error
//        os_log("UDP Stream error, no object: %{public}@ ID = %{public}@", log: self._log, type: .default, vitaPacket.classCode.description(), vitaPacket.streamId.hex)
        self._api.log.msg( "UDP Stream error, no object: \(vitaPacket.classCode.description()) ID = \(vitaPacket.streamId.hex)", level: .warning, function: #function, file: #file, line: #line)
      }
    }
  }
}

extension Radio {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _apfEnabled: Bool {
    get { return _q.sync { __apfEnabled } }
    set { _q.sync(flags: .barrier) { __apfEnabled = newValue } } }
  
  internal var _apfQFactor: Int {
    get { return _q.sync { __apfQFactor } }
    set { _q.sync(flags: .barrier) { __apfQFactor = newValue.bound(Api.kMinApfQ, Api.kMaxApfQ) } } }
  
  internal var _apfGain: Int {
    get { return _q.sync { __apfGain } }
    set { _q.sync(flags: .barrier) { __apfGain = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _availablePanadapters: Int {
    get { return _q.sync { __availablePanadapters } }
    set { _q.sync(flags: .barrier) { __availablePanadapters = newValue } } }
  
  internal var _availableSlices: Int {
    get { return _q.sync { __availableSlices } }
    set { _q.sync(flags: .barrier) { __availableSlices = newValue } } }
  
  internal var _backlight: Int {
    get { return _q.sync { __backlight } }
    set { _q.sync(flags: .barrier) { __backlight = newValue } } }
  
  internal var _bandPersistenceEnabled: Bool {
    get { return _q.sync { __bandPersistenceEnabled } }
    set { _q.sync(flags: .barrier) { __bandPersistenceEnabled = newValue } } }
  
  internal var _binauralRxEnabled: Bool {
    get { return _q.sync { __binauralRxEnabled } }
    set { _q.sync(flags: .barrier) { __binauralRxEnabled = newValue } } }
  
  internal var _calFreq: Int {
    get { return _q.sync { __calFreq } }
    set { _q.sync(flags: .barrier) { __calFreq = newValue } } }
  
  internal var _callsign: String {
    get { return _q.sync { __callsign } }
    set { _q.sync(flags: .barrier) { __callsign = newValue } } }
  
  internal var _chassisSerial: String {
    get { return _q.sync { __chassisSerial } }
    set { _q.sync(flags: .barrier) { __chassisSerial = newValue } } }
  
  internal var _boundClientId: UUID? {
    get { return _q.sync { __boundClientId } }
    set { _q.sync(flags: .barrier) { __boundClientId = newValue } } }
  
  internal var _clientIp: String {
    get { return _q.sync { __clientIp } }
    set { _q.sync(flags: .barrier) { __clientIp = newValue } } }
  
  internal var _daxIqAvailable: Int {
    get { return _q.sync { __daxIqAvailable } }
    set { _q.sync(flags: .barrier) { __daxIqAvailable = newValue } } }
  
  internal var _daxIqCapacity: Int {
    get { return _q.sync { __daxIqCapacity } }
    set { _q.sync(flags: .barrier) { __daxIqCapacity = newValue } } }
  
  internal var _enforcePrivateIpEnabled: Bool {
    get { return _q.sync { __enforcePrivateIpEnabled } }
    set { _q.sync(flags: .barrier) { __enforcePrivateIpEnabled = newValue } } }
  
  internal var _extPresent: Bool {
    get { return _q.sync { __extPresent } }
    set { _q.sync(flags: .barrier) { __extPresent = newValue } } }
  
  internal var _filterCwAutoEnabled: Bool {
    get { return _q.sync { __filterCwAutoEnabled } }
    set { _q.sync(flags: .barrier) { __filterCwAutoEnabled = newValue } } }
  
  internal var _filterDigitalAutoEnabled: Bool {
    get { return _q.sync { __filterDigitalAutoEnabled } }
    set { _q.sync(flags: .barrier) { __filterDigitalAutoEnabled = newValue } } }
  
  internal var _filterVoiceAutoEnabled: Bool {
    get { return _q.sync { __filterVoiceAutoEnabled } }
    set { _q.sync(flags: .barrier) { __filterVoiceAutoEnabled = newValue } } }
  
  internal var _filterCwLevel: Int {
    get { return _q.sync { __filterCwLevel } }
    set { _q.sync(flags: .barrier) { __filterCwLevel = newValue } } }
  
  internal var _filterDigitalLevel: Int {
    get { return _q.sync { __filterDigitalLevel } }
    set { _q.sync(flags: .barrier) { __filterDigitalLevel = newValue } } }
  
  internal var _filterVoiceLevel: Int {
    get { return _q.sync { __filterVoiceLevel } }
    set { _q.sync(flags: .barrier) { __filterVoiceLevel = newValue } } }
  
  internal var _fpgaMbVersion: String {
    get { return _q.sync { __fpgaMbVersion } }
    set { _q.sync(flags: .barrier) { __fpgaMbVersion = newValue } } }
  
  internal var _freqErrorPpb: Int {
    get { return _q.sync { __freqErrorPpb } }
    set { _q.sync(flags: .barrier) { __freqErrorPpb = newValue } } }
  
  internal var _frontSpeakerMute: Bool {
    get { return _q.sync { __frontSpeakerMute } }
    set { _q.sync(flags: .barrier) { __frontSpeakerMute = newValue } } }
  
  internal var _fullDuplexEnabled: Bool {
    get { return _q.sync { __fullDuplexEnabled } }
    set { _q.sync(flags: .barrier) { __fullDuplexEnabled = newValue } } }
  
  internal var _gateway: String {
    get { return _q.sync { __gateway } }
    set { _q.sync(flags: .barrier) { __gateway = newValue } } }
  
  internal var _gpsdoPresent: Bool {
    get { return _q.sync { __gpsdoPresent } }
    set { _q.sync(flags: .barrier) { __gpsdoPresent = newValue } } }
  
  internal var _headphoneGain: Int {
    get { return _q.sync { __headphoneGain } }
    set { _q.sync(flags: .barrier) { __headphoneGain = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _headphoneMute: Bool {
    get { return _q.sync { __headphoneMute } }
    set { _q.sync(flags: .barrier) { __headphoneMute = newValue } } }
  
  internal var _ipAddress: String {
    get { return _q.sync { __ipAddress } }
    set { _q.sync(flags: .barrier) { __ipAddress = newValue } } }
  
  internal var _location: String {
    get { return _q.sync { __location } }
    set { _q.sync(flags: .barrier) { __location = newValue } } }
  
  internal var _macAddress: String {
    get { return _q.sync { __macAddress } }
    set { _q.sync(flags: .barrier) { __macAddress = newValue } } }
  
  internal var _lineoutGain: Int {
    get { return _q.sync { __lineoutGain } }
    set { _q.sync(flags: .barrier) { __lineoutGain = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _lineoutMute: Bool {
    get { return _q.sync { __lineoutMute } }
    set { _q.sync(flags: .barrier) { __lineoutMute = newValue } } }
  
  internal var _localPtt: Bool {
    get { return _q.sync { __localPtt } }
    set { _q.sync(flags: .barrier) { __localPtt = newValue } } }
  
  internal var _locked: Bool {
    get { return _q.sync { __locked } }
    set { _q.sync(flags: .barrier) { __locked = newValue } } }
  
  internal var _mox: Bool {
    get { return _q.sync { __mox } }
    set { _q.sync(flags: .barrier) { __mox = newValue } } }
  
  internal var _muteLocalAudio: Bool {
    get { return _q.sync { __muteLocalAudio } }
    set { _q.sync(flags: .barrier) { __muteLocalAudio = newValue } } }

  internal var _netmask: String {
    get { return _q.sync { __netmask } }
    set { _q.sync(flags: .barrier) { __netmask = newValue } } }
  
  internal var _nickname: String {
    get { return _q.sync { __nickname } }
    set { _q.sync(flags: .barrier) { __nickname = newValue } } }
  
  internal var _numberOfScus: Int {
    get { return _q.sync { __numberOfScus } }
    set { _q.sync(flags: .barrier) { __numberOfScus = newValue } } }
  
  internal var _numberOfSlices: Int {
    get { return _q.sync { __numberOfSlices } }
    set { _q.sync(flags: .barrier) { __numberOfSlices = newValue } } }
  
  internal var _numberOfTx: Int {
    get { return _q.sync { __numberOfTx } }
    set { _q.sync(flags: .barrier) { __numberOfTx = newValue } } }
  
  internal var _oscillator: String {
    get { return _q.sync { __oscillator } }
    set { _q.sync(flags: .barrier) { __oscillator = newValue } } }
  
  internal var _picDecpuVersion: String {
    get { return _q.sync { __picDecpuVersion } }
    set { _q.sync(flags: .barrier) { __picDecpuVersion = newValue } } }
  
  internal var _program: String {
    get { return _q.sync { __program } }
    set { _q.sync(flags: .barrier) { __program = newValue } } }
  
  internal var _psocMbPa100Version: String {
    get { return _q.sync { __psocMbPa100Version } }
    set { _q.sync(flags: .barrier) { __psocMbPa100Version = newValue } } }
  
  internal var _psocMbtrxVersion: String {
    get { return _q.sync { __psocMbtrxVersion } }
    set { _q.sync(flags: .barrier) { __psocMbtrxVersion = newValue } } }
  
  internal var _radioModel: String {
    get { return _q.sync { __radioModel } }
    set { _q.sync(flags: .barrier) { __radioModel = newValue } } }
  
  internal var _radioOptions: String {
    get { return _q.sync { __radioOptions } }
    set { _q.sync(flags: .barrier) { __radioOptions = newValue } } }
  
  internal var _radioScreenSaver: String {
    get { return _q.sync { __radioScreenSaver } }
    set { _q.sync(flags: .barrier) { __radioScreenSaver = newValue } } }
  
  internal var _region: String {
    get { return _q.sync { __region } }
    set { _q.sync(flags: .barrier) { __region = newValue } } }
  
  internal var _remoteOnEnabled: Bool {
    get { return _q.sync { __remoteOnEnabled } }
    set { _q.sync(flags: .barrier) { __remoteOnEnabled = newValue } } }
  
  internal var _rttyMark: Int {
    get { return _q.sync { __rttyMark } }
    set { _q.sync(flags: .barrier) { __rttyMark = newValue } } }
  
  internal var _setting: String {
    get { return _q.sync { __setting } }
    set { _q.sync(flags: .barrier) { __setting = newValue } } }
  
  internal var _smartSdrMB: String {
    get { return _q.sync { __smartSdrMB } }
    set { _q.sync(flags: .barrier) { __smartSdrMB = newValue } } }
  
  internal var _snapTuneEnabled: Bool {
    get { return _q.sync { __snapTuneEnabled } }
    set { _q.sync(flags: .barrier) { __snapTuneEnabled = newValue } } }
  
  internal var _softwareVersion: String {
    get { return _q.sync { __softwareVersion } }
    set { _q.sync(flags: .barrier) { __softwareVersion = newValue } } }
  
  internal var _startCalibration: Bool {
    get { return _q.sync { __startCalibration } }
    set { _q.sync(flags: .barrier) { __startCalibration = newValue } } }
  
  internal var _state: String {
    get { return _q.sync { __state } }
    set { _q.sync(flags: .barrier) { __state = newValue } } }
  
  internal var _station: String {
    get { return _q.sync { __station } }
    set { _q.sync(flags: .barrier) { __station = newValue } } }
  
  internal var _staticGateway: String {
    get { return _q.sync { __staticGateway } }
    set { _q.sync(flags: .barrier) { __staticGateway = newValue } } }
  
  internal var _staticIp: String {
    get { return _q.sync { __staticIp } }
    set { _q.sync(flags: .barrier) { __staticIp = newValue } } }
  
  internal var _staticNetmask: String {
    get { return _q.sync { __staticNetmask } }
    set { _q.sync(flags: .barrier) { __staticNetmask = newValue } } }
  
  internal var _tcxoPresent: Bool {
    get { return _q.sync { __tcxoPresent } }
    set { _q.sync(flags: .barrier) { __tcxoPresent = newValue } } }
  
  internal var _tnfsEnabled: Bool {
    get { return _q.sync { __tnfsEnabled } }
    set { _q.sync(flags: .barrier) { __tnfsEnabled = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var atuPresent: Bool {
    return _atuPresent }
  
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
  
  @objc dynamic public var extPresent: Bool {
    return _extPresent }
  
  @objc dynamic public var fpgaMbVersion: String {
    return _fpgaMbVersion }
  
  @objc dynamic public var gateway: String {
    return _gateway }
  
  @objc dynamic public var gpsPresent: Bool {
    return _gpsPresent }
  
  @objc dynamic public var gpsdoPresent: Bool {
    return _gpsdoPresent }
  
  @objc dynamic public var ipAddress: String {
    return _ipAddress }
  
  @objc dynamic public var location: String {
    return _location }
  
  @objc dynamic public var locked: Bool {
    return _locked }
  
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
  
  @objc dynamic public var picDecpuVersion: String {
    return _picDecpuVersion }
  
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
  
  @objc dynamic public var setting: String {
    return _setting }
  
  @objc dynamic public var smartSdrMB: String {
    return _smartSdrMB }
  
  @objc dynamic public var state: String {
    return _state }
  
  @objc dynamic public var softwareVersion: String {
    return _softwareVersion }

  @objc dynamic public var tcxoPresent: Bool {
    return _tcxoPresent }
  
  // ----------------------------------------------------------------------------
  // MARK: - NON Public properties (KVO compliant)
  
  // collections
  public var amplifiers: [AmplifierId: Amplifier] {
    get { return _q.sync { _amplifiers } }
    set { _q.sync(flags: .barrier) { _amplifiers = newValue } } }
  
  public var daxIqStreams: [StreamId: DaxIqStream] {
    get { return _q.sync { _daxIqStreams } }
    set { _q.sync(flags: .barrier) { _daxIqStreams = newValue } } }
  
  public var daxMicAudioStreams: [StreamId: DaxMicAudioStream] {
    get { return _q.sync { _daxMicAudioStreams } }
    set { _q.sync(flags: .barrier) { _daxMicAudioStreams = newValue } } }
  
  public var daxRxAudioStreams: [StreamId: DaxRxAudioStream] {
    get { return _q.sync { _daxRxAudioStreams } }
    set { _q.sync(flags: .barrier) { _daxRxAudioStreams = newValue } } }
  
  public var daxTxAudioStreams: [StreamId: DaxTxAudioStream] {
    get { return _q.sync { _daxTxAudioStreams } }
    set { _q.sync(flags: .barrier) { _daxTxAudioStreams = newValue } } }
  
  public var bandSettings: [BandId: BandSetting] {
    get { return _q.sync { _bandSettings } }
    set { _q.sync(flags: .barrier) { _bandSettings = newValue } } }
  
  public var equalizers: [Equalizer.EqType: Equalizer] {
    get { return _q.sync { _equalizers } }
    set { _q.sync(flags: .barrier) { _equalizers = newValue } } }
  
  public var memories: [MemoryId: Memory] {
    get { return _q.sync { _memories } }
    set { _q.sync(flags: .barrier) { _memories = newValue } } }
  
  public var meters: [MeterNumber: Meter] {
    get { return _q.sync { _meters } }
    set { _q.sync(flags: .barrier) { _meters = newValue } } }
  
  public var opusStreams: [OpusId: Opus] {
    get { return _q.sync { _opusStreams } }
    set { _q.sync(flags: .barrier) { _opusStreams = newValue } } }
  
  public var panadapters: [PanadapterId: Panadapter] {
    get { return _q.sync { _panadapters } }
    set { _q.sync(flags: .barrier) { _panadapters = newValue } } }
  
  public var profiles: [ProfileId: Profile] {
    get { return _q.sync { _profiles } }
    set { _q.sync(flags: .barrier) { _profiles = newValue } } }
  
  public var replyHandlers: [SequenceId: ReplyTuple] {
    get { return _q.sync { _replyHandlers } }
    set { _q.sync(flags: .barrier) { _replyHandlers = newValue } } }
  
  public var slices: [SliceId: Slice] {
    get { return _q.sync { _slices } }
    set { _q.sync(flags: .barrier) { _slices = newValue } } }
  
  public var tnfs: [TnfId: Tnf] {
    get { return _q.sync { _tnfs } }
    set { _q.sync(flags: .barrier) { _tnfs = newValue } } }
  
  public var waterfalls: [WaterfallId: Waterfall] {
    get { return _q.sync { _waterfalls } }
    set { _q.sync(flags: .barrier) { _waterfalls = newValue } } }
  
  public var usbCables: [UsbCableId: UsbCable] {
    get { return _q.sync { _usbCables } }
    set { _q.sync(flags: .barrier) { _usbCables = newValue } } }
  
  public var xvtrs: [XvtrId: Xvtr] {
    get { return _q.sync { _xvtrs } }
    set { _q.sync(flags: .barrier) { _xvtrs = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Clients
  ///
  internal enum ClientToken : String {
    case host
    case id                             = "client_id"
    case ip
    case localPttEnabled                = "local_ptt"
    case program
    case station
  }
  /// Types
  ///
  internal enum DisplayToken: String {
    case panadapter                         = "pan"
    case waterfall
  }
  /// EqApf
  ///
  internal enum EqApfToken: String {
    case gain
    case mode
    case qFactor
  }
  /// Info properties
  ///
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
  /// Radio properties
  ///
  internal enum RadioToken: String {
    case backlight
    case bandPersistenceEnabled             = "band_persistence_enabled"
    case binauralRxEnabled                  = "binaural_rx"
    case calFreq                            = "cal_freq"
    case callsign
    case daxIqAvailable                     = "daxiq_available"
    case daxIqCapacity                      = "daxiq_capacity"
    case enforcePrivateIpEnabled            = "enforce_private_ip_connections"
    case freqErrorPpb                       = "freq_error_ppb"
    case frontSpeakerMute                   = "front_speaker_mute"
    case fullDuplexEnabled                  = "full_duplex_enabled"
    case headphoneGain                      = "headphone_gain"                  // "headphone gain"
    case headphoneMute                      = "headphone_mute"                  // "headphone mute"
    case lineoutGain                        = "lineout_gain"                    // "lineout gain"
    case lineoutMute                        = "lineout_mute"                    // "lineout mute"
    case muteLocalAudio                     = "mute_local_audio_when_remote"
    case nickname                                                               // "name"
    case panadapters
    case pllDone                            = "pll_done"
    case remoteOnEnabled                    = "remote_on_enabled"
    case rttyMark                           = "rtty_mark_default"
    case slices
    case snapTuneEnabled                    = "snap_tune_enabled"
    case tnfsEnabled                        = "tnf_enabled"
  }
  /// Radio categories
  ///
  internal enum RadioTokenCategory: String {
    case filterSharpness                    = "filter_sharpness"
    case staticNetParams                    = "static_net_params"
    case oscillator
  }
  /// Sharpness properties
  ///
  internal enum RadioFilterSharpness: String {
    case cw
    case CW
    case digital
    case DIGITAL
    case voice
    case VOICE
    case autoLevel                          = "auto_level"
    case level
  }
  /// Static Net properties
  ///
  internal enum RadioStaticNet: String {
    case gateway
    case ip
    case netmask
  }
  /// Oscillator properties
  ///
  internal enum RadioOscillator: String {
    case extPresent                         = "ext_present"
    case gpsdoPresent                       = "gpsdo_present"
    case locked
    case setting
    case state
    case tcxoPresent                        = "tcxo_present"
  }
  /// Status properties
  ///
  internal enum StatusToken : String {
    case amplifier
//    case audioStream                        = "audio_stream"
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
//    case micAudioStream                     = "mic_audio_stream"
    case mixer
    case opusStream                         = "opus_stream"
    case profile
    case radio
    case slice
    case stream
    case tnf
    case transmit
    case turf
//    case txAudioStream                      = "tx_audio_stream"
    case usbCable                           = "usb_cable"
    case wan
    case waveform
    case xvtr
  }
  /// Version properties
  ///
  internal enum VersionToken: String {
    case fpgaMb                             = "fpga-mb"
    case psocMbPa100                        = "psoc-mbpa100"
    case psocMbTrx                          = "psoc-mbtrx"
    case smartSdrMB                         = "smartsdr-mb"
    case picDecpu                           = "pic-decpu"
  }
  /// Filter properties
  ///
  public struct FilterSpec {
    var filterHigh                          : Int
    var filterLow                           : Int
    var label                               : String
    var mode                                : String
    var txFilterHigh                        : Int
    var txFilterLow                         : Int
  }
  /// Tx Filter properties
  ///
  public struct TxFilter {
    var high                                = 0
    var low                                 = 0
  }
  
  // --------------------------------------------------------------------------------
  // MARK: - Aliases
  
  public typealias AntennaPort              = String
  public typealias FilterMode               = String
  public typealias MicrophonePort           = String
  public typealias RfGainValue              = String
}
