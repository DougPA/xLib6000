//
//  Slice.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

public typealias SliceId = String

// ------------------------------------------------------------------------------
// MARK: - Slice Class implementation
//
//      creates a Slice instance to be used by a Client to support the
//      rendering of a Slice. Slice objects are added, removed and
//      updated by the incoming TCP messages.
//
// ------------------------------------------------------------------------------

public final class Slice                    : NSObject, StatusParser, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : SliceId = ""                  // Id that uniquely identifies this Slice
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio (hardware)

  private let kTuneStepList                 =                               // tuning steps
    [1, 10, 50, 100, 500, 1_000, 2_000, 3_000]
  private var _diversityIsAllowed          : Bool
    { return Api.sharedInstance.activeRadio?.model == "FLEX-6700" || Api.sharedInstance.activeRadio?.model == "FLEX-6700R" }

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ---------
  //
  private var _meters                       = [String: Meter]()             // Dictionary of Meters (on this Slice)
  //
  private var __daxClients                  = 0                             // DAX clients for this slice
  //
  private var __active                      = false                         //
  private var __agcMode                     = AgcMode.off.rawValue          //
  private var __agcOffLevel                 = 0                             // Slice AGC Off level
  private var __agcThreshold                = 0                             //
  private var __anfEnabled                  = false                         //
  private var __anfLevel                    = 0                             //
  private var __apfEnabled                  = false                         //
  private var __apfLevel                    = 0                             // DSP APF Level (0 - 100)
  private var __audioGain                   = 0                             // Slice audio gain (0 - 100)
  private var __audioMute                   = false                         // State of slice audio MUTE
  private var __audioPan                    = 50                            // Slice audio pan (0 - 100)
  private var __autoPan                     = false                         // panadapter frequency follows slice
  private var __daxChannel                  = 0                             // DAX channel for this slice (1-8)
  private var __daxTxEnabled                = false                         // DAX for transmit
  private var __dfmPreDeEmphasisEnabled     = false                         //
  private var __digitalLowerOffset          = 0                             //
  private var __digitalUpperOffset          = 0                             //
  private var __diversityChild              = false                         // Slice is the child of the pair
  private var __diversityEnabled            = false                         // Slice is part of a diversity pair
  private var __diversityIndex              = 0                             // Slice number of the other slice
  private var __diversityParent             = false                         // Slice is the parent of the pair
  private var __filterHigh                  = 0                             // RX filter high frequency
  private var __filterLow                   = 0                             // RX filter low frequency
  private var __fmDeviation                 = 0                             // FM deviation
  private var __fmRepeaterOffset            : Float = 0.0                   // FM repeater offset
  private var __fmToneBurstEnabled          = false                         // FM tone burst
  private var __fmToneFreq                  : Float = 0.0                   // FM CTCSS tone frequency
  private var __fmToneMode                  = ""                            // FM CTCSS tone mode (ON | OFF)
  private var __frequency                   = 0                             // Slice frequency in Hz
  private var __inUse                       = false                         // True = being used
  private var __locked                      = false                         // Slice frequency locked
  private var __loopAEnabled                = false                         // Loop A enable
  private var __loopBEnabled                = false                         // Loop B enable
  private var __mode                        = Mode.lsb.rawValue             // Slice mode
  private var __modeList                    = [String]()                    // Array of Strings with available modes
  private var __nbEnabled                   = false                         // State of DSP Noise Blanker
  private var __nbLevel                     = 0                             // DSP Noise Blanker level (0 -100)
  private var __nrEnabled                   = false                         // State of DSP Noise Reduction
  private var __nrLevel                     = 0                             // DSP Noise Reduction level (0 - 100)
  private var __owner                       = 0                             // Slice owner - RESERVED for FUTURE use
  private var __panadapterId                : PanadapterId = 0              // Panadaptor StreamID for this slice
  private var __playbackEnabled             = false                         // Quick playback enable
  private var __postDemodBypassEnabled      = false                         //
  private var __postDemodHigh               = 0                             //
  private var __postDemodLow                = 0                             //
  private var __qskEnabled                  = false                         // QSK capable on slice
  private var __recordEnabled               = false                         // Quick record enable
  private var __recordLength                : Float = 0.0                   // Length of quick recording (seconds)
  private var __repeaterOffsetDirection     = RepeaterOffsetDirection.simplex.rawValue // Repeater offset direction (DOWN, UP, SIMPLEX)
  private var __rfGain                      = 0                             // RF Gain
  private var __ritEnabled                  = false                         // RIT enabled
  private var __ritOffset                   = 0                             // RIT offset value
  private var __rttyMark                    = 0                             // Rtty Mark
  private var __rttyShift                   = 0                             // Rtty Shift
  private var __rxAnt                       = ""                            // RX Antenna port for this slice
  private var __rxAntList                   = [String]()                    // Array of available Rx Antenna ports
  private var __step                        = 0                             // Frequency step value
  private var __squelchEnabled              = false                         // Squelch enabled
  private var __squelchLevel                = 0                             // Squelch level (0 - 100)
  private var __stepList                    = ""                            // Available Step values
  private var __txAnt                       = ""                            // TX Antenna port for this slice
  private var __txAntList                   = [String]()                    // Array of available Tx Antenna ports
  private var __txEnabled                   = false                         // TX on ths slice frequency/mode
  private var __txOffsetFreq                : Float = 0.0                   // TX Offset Frequency
  private var __wide                        = false                         // State of slice bandpass filter
  private var __wnbEnabled                  = false                         // Wideband noise blanking enabled
  private var __wnbLevel                    = 0                             // Wideband noise blanking level
  private var __xitEnabled                  = false                         // XIT enable
  private var __xitOffset                   = 0                             // XIT offset value
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ---------
  
  // ----------------------------------------------------------------------------
  // MARK: - StatusParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a Slice status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    
    // get the Slice Id
    let sliceId = keyValues[0].key
    
    // is the Slice in use?
    if inUse {
      
      // YES, does the Slice exist?
      if radio.slices[sliceId] == nil {
        
        // NO, create a new Slice & add it to the Slices collection
        radio.slices[sliceId] = xLib6000.Slice(id: sliceId, queue: queue)
        
        // scan the meters
        for (_, meter) in radio.meters {
          
          // is this meter associated with this slice?
          if meter.source == Meter.Source.slice.rawValue && meter.number == sliceId {
            
            // YES, add it to this Slice
            radio.slices[sliceId]!.addMeter(meter)
          }
        }
      }
      // pass the remaining key values to the Slice for parsing (dropping the Id)
      radio.slices[sliceId]!.parseProperties( Array(keyValues.dropFirst(1)) )
      
    } else {
      
      // NO, notify all observers
      NC.post(.sliceWillBeRemoved, object: radio.slices[sliceId] as Any?)
      
      // remove it
      radio.slices[sliceId] = nil
      
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Slice
  ///
  /// - Parameters:
  ///   - sliceId:            a Slice Id
  ///   - radio:              parent Radio class
  ///   - queue:              Concurrent queue
  ///
  public init(id: SliceId, queue: DispatchQueue) {

    self.id = id
    _q = queue
    
    super.init()
    
    // setup the Step List
    var stepListString = kTuneStepList.reduce("") {start , value in "\(start), \(String(describing: value))" }
    stepListString = String(stepListString.dropLast())
    _stepList = stepListString
    
    // set filterLow & filterHigh to default values
    setupDefaultFilters(_mode)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send commands to the Radio (hardware)
  
  public func setRecord(_ value: Bool) { Api.sharedInstance.send(xLib6000.Slice.kSetCmd + "\(id) record=\(value.asNumber())") }
  public func setPlay(_ value: Bool) { Api.sharedInstance.send(xLib6000.Slice.kSetCmd + "\(id) play=\(value.asNumber())") }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Add a Meter to this Slice's Meters collection
  ///
  /// - Parameters:
  ///   - meter:      a reference to a Meter
  ///
  func addMeter(_ meter: Meter) {
    meters[meter.id] = meter
  }
  /// Remove a Meter from this Slice's Meters collection
  ///
  /// - Parameters:
  ///   - meter:      a reference to a Meter
  ///
  func removeMeter(_ id: MeterId) {
    meters[id] = nil
  }
  /// Set the default Filter widths
  ///
  /// - Parameters:
  ///   - mode:       demod mode
  ///
  func setupDefaultFilters(_ mode: String) {
    
    if let modeValue = Mode(rawValue: mode) {
      
      switch modeValue {
        
      case .cw:
        _filterLow = 450
        _filterHigh = 750
        
      case .rtty:
        _filterLow = -285
        _filterHigh = 115
        
      case .dsb:
        _filterLow = -2_400
        _filterHigh = 2_400
        
      case .am, .sam:
        _filterLow = -3_000
        _filterHigh = 3_000
        
      case .fm, .nfm, .dfm, .dstr:
        _filterLow = -8_000
        _filterHigh = 8_000
        
      case .lsb, .digl:
        _filterLow = -2_400
        _filterHigh = -300
        
      case .usb, .digu, .fdv:
        _filterLow = 300
        _filterHigh = 2_400
      }
    }
  }
  /// Restrict the Filter High value
  ///
  /// - Parameters:
  ///   - value:          the value
  /// - Returns:          adjusted value
  ///
  func filterHighLimits(_ value: Int) -> Int {
    
    var newValue = (value < filterLow + 10 ? filterLow + 10 : value)
    
    if let modeType = Mode(rawValue: mode.lowercased()) {
      switch modeType {
        
      case .fm, .nfm:
        Log.sharedInstance.msg("Cannot change Filter width in FM mode", level: .warning, function: #function, file: #file, line: #line)
        newValue = value
        
      case .cw:
        newValue = (newValue > 12_000 - Api.sharedInstance.radio!.transmit.cwPitch ? 12_000 - Api.sharedInstance.radio!.transmit.cwPitch : newValue)
        
      case .rtty:
        newValue = (newValue > rttyMark ? rttyMark : newValue)
        newValue = (newValue < 50 ? 50 : newValue)
        
      case .dsb, .am, .sam, .dfm, .dstr:
        newValue = (newValue > 12_000 ? 12_000 : newValue)
        newValue = (newValue < 10 ? 10 : newValue)
        
      case .lsb, .digl:
        newValue = (newValue > 0 ? 0 : newValue)
        
      case .usb, .digu, .fdv:
        newValue = (newValue > 12_000 ? 12_000 : newValue)
      }
    }
    return newValue
  }
  /// Restrict the Filter Low value
  ///
  /// - Parameters:
  ///   - value:          the value
  /// - Returns:          adjusted value
  ///
  func filterLowLimits(_ value: Int) -> Int {
    
    var newValue = (value > filterHigh - 10 ? filterHigh - 10 : value)
    
    if let modeType = Mode(rawValue: mode.lowercased()) {
      switch modeType {
        
      case .fm, .nfm:
        Log.sharedInstance.msg("Cannot change Filter width in FM mode", level: .warning, function: #function, file: #file, line: #line)
        newValue = value
        
      case .cw:
        newValue = (newValue < -12_000 - Api.sharedInstance.radio!.transmit.cwPitch ? -12_000 - Api.sharedInstance.radio!.transmit.cwPitch : newValue)
        
      case .rtty:
        newValue = (newValue < -12_000 + rttyMark ? -12_000 + rttyMark : newValue)
        newValue = (newValue > -(50 + rttyShift) ? -(50 + rttyShift) : newValue)
        
      case .dsb, .am, .sam, .dfm, .dstr:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
        newValue = (newValue > -10 ? -10 : newValue)
        
      case .lsb, .digl:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
        
      case .usb, .digu, .fdv:
        newValue = (newValue < 0 ? 0 : newValue)
      }
    }
    return newValue
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse Slice key/value pairs
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
      // Known keys, in alphabetical order
      switch token {
        
      case .active:
        willChangeValue(forKey: "active")
        _active = property.value.bValue()
        didChangeValue(forKey: "active")
        
      case .agcMode:
        willChangeValue(forKey: "agcMode")
        _agcMode = property.value
        didChangeValue(forKey: "agcMode")
        
      case .agcOffLevel:
        willChangeValue(forKey: "agcOffLevel")
        _agcOffLevel = property.value.iValue()
        didChangeValue(forKey: "agcOffLevel")
        
      case .agcThreshold:
        willChangeValue(forKey: "agcThreshold")
        _agcThreshold = property.value.iValue()
        didChangeValue(forKey: "agcThreshold")
        
      case .anfEnabled:
        willChangeValue(forKey: "anfEnabled")
        _anfEnabled = property.value.bValue()
        didChangeValue(forKey: "anfEnabled")
        
      case .anfLevel:
        willChangeValue(forKey: "anfLevel")
        _anfLevel = property.value.iValue()
        didChangeValue(forKey: "anfLevel")
        
      case .apfEnabled:
        willChangeValue(forKey: "apfEnabled")
        _apfEnabled = property.value.bValue()
        didChangeValue(forKey: "apfEnabled")
        
      case .apfLevel:
        willChangeValue(forKey: "apfLevel")
        _apfLevel = property.value.iValue()
        didChangeValue(forKey: "apfLevel")
        
      case .audioGain:
        willChangeValue(forKey: "audioGain")
        _audioGain = property.value.iValue()
        didChangeValue(forKey: "audioGain")
        
      case .audioMute:
        willChangeValue(forKey: "audioMute")
        _audioMute = property.value.bValue()
        didChangeValue(forKey: "audioMute")
        
      case .audioPan:
        willChangeValue(forKey: "audioPan")
        _audioPan = property.value.iValue()
        didChangeValue(forKey: "audioPan")
        
      case .daxChannel:
        willChangeValue(forKey: "daxChannel")
        _daxChannel = property.value.iValue()
        didChangeValue(forKey: "daxChannel")
        
      case .daxTxEnabled:
        willChangeValue(forKey: "daxTxEnabled")
        _daxTxEnabled = property.value.bValue()
        didChangeValue(forKey: "daxTxEnabled")
        
      case .dfmPreDeEmphasisEnabled:
        willChangeValue(forKey: "dfmPreDeEmphasisEnabled")
        _dfmPreDeEmphasisEnabled = property.value.bValue()
        didChangeValue(forKey: "dfmPreDeEmphasisEnabled")
        
      case .digitalLowerOffset:
        willChangeValue(forKey: "digitalLowerOffset")
        _digitalLowerOffset = property.value.iValue()
        didChangeValue(forKey: "digitalLowerOffset")
        
      case .digitalUpperOffset:
        willChangeValue(forKey: "digitalUpperOffset")
        _digitalUpperOffset = property.value.iValue()
        didChangeValue(forKey: "digitalUpperOffset")
        
      case .diversityEnabled:
        if _diversityIsAllowed {
          willChangeValue(forKey: "diversityEnabled")
          _diversityEnabled = property.value.bValue()
          didChangeValue(forKey: "diversityEnabled")
        }
        
      case .diversityChild:
        if _diversityIsAllowed {
          willChangeValue(forKey: "diversityChild")
          _diversityChild = property.value.bValue()
          didChangeValue(forKey: "diversityChild")
        }
        
      case .diversityIndex:
        if _diversityIsAllowed {
          willChangeValue(forKey: "diversityIndex")
          _diversityIndex = property.value.iValue()
          didChangeValue(forKey: "diversityIndex")
        }
        
      case .filterHigh:
        willChangeValue(forKey: "filterHigh")
        _filterHigh = property.value.iValue()
        didChangeValue(forKey: "filterHigh")
        
      case .filterLow:
        willChangeValue(forKey: "filterLow")
        _filterLow = property.value.iValue()
        didChangeValue(forKey: "filterLow")
        
      case .fmDeviation:
        willChangeValue(forKey: "fmDeviation")
        _fmDeviation = property.value.iValue()
        didChangeValue(forKey: "fmDeviation")
        
      case .fmRepeaterOffset:
        willChangeValue(forKey: "fmRepeaterOffset")
        _fmRepeaterOffset = property.value.fValue()
        didChangeValue(forKey: "fmRepeaterOffset")
        
      case .fmToneBurstEnabled:
        willChangeValue(forKey: "fmToneBurstEnabled")
        _fmToneBurstEnabled = property.value.bValue()
        didChangeValue(forKey: "fmToneBurstEnabled")
        
      case .fmToneMode:
        willChangeValue(forKey: "fmToneMode")
        _fmToneMode = property.value
        didChangeValue(forKey: "fmToneMode")
        
      case .fmToneFreq:
        willChangeValue(forKey: "fmToneFreq")
        _fmToneFreq = property.value.fValue()
        didChangeValue(forKey: "fmToneFreq")
        
      case .frequency:
        willChangeValue(forKey: "frequency")
        _frequency = property.value.mhzToHz()
        didChangeValue(forKey: "frequency")
        
      case .ghost:
        // FIXME: Is this needed?
        Log.sharedInstance.msg("Unknown token - \(property.key),\(property.value)", level: .debug, function: #function, file: #file, line: #line)
        
      case .inUse:
        willChangeValue(forKey: "inUse")
        _inUse = property.value.bValue()
        didChangeValue(forKey: "inUse")
        
      case .locked:
        willChangeValue(forKey: "locked")
        _locked = property.value.bValue()
        didChangeValue(forKey: "locked")
        
      case .loopAEnabled:
        willChangeValue(forKey: "loopAEnabled")
        _loopAEnabled = property.value.bValue()
        didChangeValue(forKey: "loopAEnabled")
        
      case .loopBEnabled:
        willChangeValue(forKey: "loopBEnabled")
        _loopBEnabled = property.value.bValue()
        didChangeValue(forKey: "loopBEnabled")
        
      case .mode:
        willChangeValue(forKey: "mode")
        _mode = property.value
        didChangeValue(forKey: "mode")
        
      case .modeList:
        willChangeValue(forKey: "modeList")
        _modeList = property.value.components(separatedBy: ",")
        didChangeValue(forKey: "modeList")
        
      case .nbEnabled:
        willChangeValue(forKey: "nbEnabled")
        _nbEnabled = property.value.bValue()
        didChangeValue(forKey: "nbEnabled")
        
      case .nbLevel:
        willChangeValue(forKey: "nbLevel")
        _nbLevel = property.value.iValue()
        didChangeValue(forKey: "nbLevel")
        
      case .nrEnabled:
        willChangeValue(forKey: "nrEnabled")
        _nrEnabled = property.value.bValue()
        didChangeValue(forKey: "nrEnabled")
        
      case .nrLevel:
        willChangeValue(forKey: "nrLevel")
        _nrLevel = property.value.iValue()
        didChangeValue(forKey: "nrLevel")
        
      case .owner:
        willChangeValue(forKey: "owner")
        _owner = property.value.iValue()
        didChangeValue(forKey: "owner")
        
      case .panadapterId:     // does have leading "0x"
        willChangeValue(forKey: "panadapterId")
        _panadapterId = UInt32(property.value.dropFirst(2), radix: 16) ?? 0
        didChangeValue(forKey: "panadapterId")
        
      case .playbackEnabled:
        willChangeValue(forKey: "playbackEnabled")
        _playbackEnabled = (property.value == "enabled") || (property.value == "1")
        didChangeValue(forKey: "playbackEnabled")
        
      case .postDemodBypassEnabled:
        willChangeValue(forKey: "postDemodBypassEnabled")
        _postDemodBypassEnabled = property.value.bValue()
        didChangeValue(forKey: "postDemodBypassEnabled")
        
      case .postDemodLow:
        willChangeValue(forKey: "postDemodLow")
        _postDemodLow = property.value.iValue()
        didChangeValue(forKey: "postDemodLow")
        
      case .postDemodHigh:
        willChangeValue(forKey: "postDemodHigh")
        _postDemodHigh = property.value.iValue()
        didChangeValue(forKey: "postDemodHigh")
        
      case .qskEnabled:
        willChangeValue(forKey: "qskEnabled")
        _qskEnabled = property.value.bValue()
        didChangeValue(forKey: "qskEnabled")
        
      case .recordEnabled:
        willChangeValue(forKey: "recordEnabled")
        _recordEnabled = property.value.bValue()
        didChangeValue(forKey: "recordEnabled")
        
      case .repeaterOffsetDirection:
        willChangeValue(forKey: "repeaterOffsetDirection")
        _repeaterOffsetDirection = property.value
        didChangeValue(forKey: "repeaterOffsetDirection")
        
      case .rfGain:
        willChangeValue(forKey: "rfGain")
        _rfGain = property.value.iValue()
        didChangeValue(forKey: "rfGain")
        
      case .ritOffset:
        willChangeValue(forKey: "ritOffset")
        _ritOffset = property.value.iValue()
        didChangeValue(forKey: "ritOffset")
        
      case .ritEnabled:
        willChangeValue(forKey: "ritEnabled")
        _ritEnabled = property.value.bValue()
        didChangeValue(forKey: "ritEnabled")
        
      case .rttyMark:
        willChangeValue(forKey: "rttyMark")
        _rttyMark = property.value.iValue()
        didChangeValue(forKey: "rttyMark")
        
      case .rttyShift:
        willChangeValue(forKey: "rttyShift")
        _rttyShift = property.value.iValue()
        didChangeValue(forKey: "rttyShift")
        
      case .rxAnt:
        willChangeValue(forKey: "rxAnt")
        _rxAnt = property.value
        didChangeValue(forKey: "rxAnt")
        
      case .rxAntList:
        willChangeValue(forKey: "rxAntList")
        _rxAntList = property.value.components(separatedBy: ",")
        didChangeValue(forKey: "rxAntList")
        
      case .squelchEnabled:
        willChangeValue(forKey: "squelchEnabled")
        _squelchEnabled = property.value.bValue()
        didChangeValue(forKey: "squelchEnabled")
        
      case .squelchLevel:
        willChangeValue(forKey: "squelchLevel")
        _squelchLevel = property.value.iValue()
        didChangeValue(forKey: "squelchLevel")
        
      case .step:
        willChangeValue(forKey: "step")
        _step = property.value.iValue()
        didChangeValue(forKey: "step")
        
      case .stepList:
        willChangeValue(forKey: "stepList")
        _stepList = property.value
        didChangeValue(forKey: "stepList")
        
      case .txEnabled:
        willChangeValue(forKey: "txEnabled")
        _txEnabled = property.value.bValue()
        didChangeValue(forKey: "txEnabled")
        
      case .txAnt:
        willChangeValue(forKey: "txAnt")
        _txAnt = property.value
        didChangeValue(forKey: "txAnt")
        
      case .txAntList:
        willChangeValue(forKey: "txAntList")
        _txAntList = property.value.components(separatedBy: ",")
        didChangeValue(forKey: "txAntList")
        
      case .txOffsetFreq:
        willChangeValue(forKey: "txOffsetFreq")
        _txOffsetFreq = property.value.fValue()
        didChangeValue(forKey: "txOffsetFreq")
        
      case .wide:
        willChangeValue(forKey: "wide")
        _wide = property.value.bValue()
        didChangeValue(forKey: "wide")
        
      case .wnbEnabled:
        willChangeValue(forKey: "wnbEnabled")
        _wnbEnabled = property.value.bValue()
        didChangeValue(forKey: "wnbEnabled")
        
      case .wnbLevel:
        willChangeValue(forKey: "wnbLevel")
        _wnbLevel = property.value.iValue()
        didChangeValue(forKey: "wnbLevel")
        
      case .xitOffset:
        willChangeValue(forKey: "xitOffset")
        _xitOffset = property.value.iValue()
        didChangeValue(forKey: "xitOffset")
        
      case .xitEnabled:
        willChangeValue(forKey: "xitEnabled")
        _xitEnabled = property.value.bValue()
        didChangeValue(forKey: "xitEnabled")
        
      case .daxClients, .diversityParent, .recordTime:
        // ignore these
        break
      }
    }
    // if this is not yet initialized and inUse becomes true and panadapterId & frequency are set
    if _initialized == false && inUse == true && panadapterId != 0 && frequency != 0 && mode != "" {
      
      // mark it as initialized
      _initialized = true
      
      // notify all observers
      NC.post(.sliceHasBeenAdded, object: self)
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Slice Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Slice tokens
//              - Slice related enums
// --------------------------------------------------------------------------------

extension xLib6000.Slice {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _active: Bool {
    get { return _q.sync { __active } }
    set { _q.sync(flags: .barrier) {__active = newValue } } }
  
  internal var _agcMode: String {
    get { return _q.sync { __agcMode } }
    set { _q.sync(flags: .barrier) { __agcMode = newValue } } }
  
  internal var _agcOffLevel: Int {
    get { return _q.sync { __agcOffLevel } }
    set { _q.sync(flags: .barrier) { __agcOffLevel = newValue } } }
  
  internal var _agcThreshold: Int {
    get { return _q.sync { __agcThreshold } }
    set { _q.sync(flags: .barrier) { __agcThreshold = newValue } } }
  
  internal var _anfEnabled: Bool {
    get { return _q.sync { __anfEnabled } }
    set { _q.sync(flags: .barrier) { __anfEnabled = newValue } } }
  
  internal var _anfLevel: Int {
    get { return _q.sync { __anfLevel } }
    set { _q.sync(flags: .barrier) { __anfLevel = newValue } } }
  
  internal var _apfEnabled: Bool {
    get { return _q.sync { __apfEnabled } }
    set { _q.sync(flags: .barrier) { __apfEnabled = newValue } } }
  
  internal var _apfLevel: Int {
    get { return _q.sync { __apfLevel } }
    set { _q.sync(flags: .barrier) { __apfLevel = newValue } } }
  
  internal var _audioGain: Int {
    get { return _q.sync { __audioGain } }
    set { _q.sync(flags: .barrier) { __audioGain = newValue } } }
  
  internal var _audioMute: Bool {
    get { return _q.sync { __audioMute } }
    set { _q.sync(flags: .barrier) { __audioMute = newValue } } }
  
  internal var _audioPan: Int {
    get { return _q.sync { __audioPan } }
    set { _q.sync(flags: .barrier) { __audioPan = newValue } } }
  
  internal var _autoPan: Bool {
    get { return _q.sync { __autoPan } }
    set { _q.sync(flags: .barrier) { __autoPan = newValue } } }
  
  internal var _daxChannel: Int {
    get { return _q.sync { __daxChannel } }
    set { _q.sync(flags: .barrier) { __daxChannel = newValue } } }
  
  internal var _daxClients: Int {
    get { return _q.sync { __daxClients } }
    set { _q.sync(flags: .barrier) { __daxClients = newValue } } }
  
  internal var _dfmPreDeEmphasisEnabled: Bool {
    get { return _q.sync { __dfmPreDeEmphasisEnabled } }
    set { _q.sync(flags: .barrier) { __dfmPreDeEmphasisEnabled = newValue } } }
  
  internal var _daxTxEnabled: Bool {
    get { return _q.sync { __daxTxEnabled } }
    set { _q.sync(flags: .barrier) { __daxTxEnabled = newValue } } }
  
  internal var _digitalLowerOffset: Int {
    get { return _q.sync { __digitalLowerOffset } }
    set { _q.sync(flags: .barrier) { __digitalLowerOffset = newValue } } }
  
  internal var _digitalUpperOffset: Int {
    get { return _q.sync { __digitalUpperOffset } }
    set { _q.sync(flags: .barrier) { __digitalUpperOffset = newValue } } }
  
  internal var _diversityChild: Bool {
    get { return _q.sync { __diversityChild } }
    set { _q.sync(flags: .barrier) { __diversityChild = newValue } } }
  
  internal var _diversityEnabled: Bool {
    get { return _q.sync { __diversityEnabled } }
    set { _q.sync(flags: .barrier) { __diversityEnabled = newValue } } }
  
  internal var _diversityIndex: Int {
    get { return _q.sync { __diversityIndex } }
    set { _q.sync(flags: .barrier) { __diversityIndex = newValue } } }
  
  internal var _diversityParent: Bool {
    get { return _q.sync { __diversityParent } }
    set { _q.sync(flags: .barrier) { __diversityParent = newValue } } }
  
  internal var _filterHigh: Int {
    get { return _q.sync { __filterHigh } }
    set { _q.sync(flags: .barrier) { __filterHigh = newValue } } }
  
  internal var _filterLow: Int {
    get { return _q.sync { __filterLow } }
    set {_q.sync(flags: .barrier) { __filterLow = newValue } } }
  
  internal var _fmDeviation: Int {
    get { return _q.sync { __fmDeviation } }
    set { _q.sync(flags: .barrier) { __fmDeviation = newValue } } }
  
  internal var _fmRepeaterOffset: Float {
    get { return _q.sync { __fmRepeaterOffset } }
    set { _q.sync(flags: .barrier) { __fmRepeaterOffset = newValue } } }
  
  internal var _fmToneBurstEnabled: Bool {
    get { return _q.sync { __fmToneBurstEnabled } }
    set { _q.sync(flags: .barrier) { __fmToneBurstEnabled = newValue } } }
  
  internal var _fmToneFreq: Float {
    get { return _q.sync { __fmToneFreq } }
    set { _q.sync(flags: .barrier) { __fmToneFreq = newValue } } }
  
  internal var _fmToneMode: String {
    get { return _q.sync { __fmToneMode } }
    set { _q.sync(flags: .barrier) { __fmToneMode = newValue } } }
  
  internal var _frequency: Int {
    get { return _q.sync { __frequency } }
    set { _q.sync(flags: .barrier) { __frequency = newValue } } }
  
  internal var _inUse: Bool {
    get { return _q.sync { __inUse } }
    set { _q.sync(flags: .barrier) { __inUse = newValue } } }
  
  internal var _locked: Bool {
    get { return _q.sync { __locked } }
    set { _q.sync(flags: .barrier) { __locked = newValue } } }
  
  internal var _loopAEnabled: Bool {
    get { return _q.sync { __loopAEnabled } }
    set { _q.sync(flags: .barrier) { __loopAEnabled = newValue } } }
  
  internal var _loopBEnabled: Bool {
    get { return _q.sync { __loopBEnabled } }
    set { _q.sync(flags: .barrier) { __loopBEnabled = newValue } } }
  
  internal var _mode: String {
    get { return _q.sync { __mode } }
    set { _q.sync(flags: .barrier) { __mode = newValue } } }
  
  internal var _modeList: [String] {
    get { return _q.sync { __modeList } }
    set { _q.sync(flags: .barrier) { __modeList = newValue } } }
  
  internal var _nbEnabled: Bool {
    get { return _q.sync { __nbEnabled } }
    set { _q.sync(flags: .barrier) { __nbEnabled = newValue } } }
  
  internal var _nbLevel: Int {
    get { return _q.sync { __nbLevel } }
    set { _q.sync(flags: .barrier) { __nbLevel = newValue } } }
  
  internal var _nrEnabled: Bool {
    get { return _q.sync { __nrEnabled } }
    set { _q.sync(flags: .barrier) { __nrEnabled = newValue } } }
  
  internal var _nrLevel: Int {
    get { return _q.sync { __nrLevel } }
    set { _q.sync(flags: .barrier) { __nrLevel = newValue } } }
  
  internal var _owner: Int {
    get { return _q.sync { __owner } }
    set { _q.sync(flags: .barrier) { __owner = newValue } } }
  
  internal var _panadapterId: PanadapterId {
    get { return _q.sync { __panadapterId } }
    set { _q.sync(flags: .barrier) { __panadapterId = newValue } } }
  
  internal var _panControl: Int {
    get { return _q.sync { __audioPan } }
    set { _q.sync(flags: .barrier) { __audioPan = newValue } } }
  
  internal var _playbackEnabled: Bool {
    get { return _q.sync { __playbackEnabled } }
    set { _q.sync(flags: .barrier) { __playbackEnabled = newValue } } }
  
  internal var _postDemodBypassEnabled: Bool {
    get { return _q.sync { __postDemodBypassEnabled } }
    set { _q.sync(flags: .barrier) { __postDemodBypassEnabled = newValue } } }
  
  internal var _postDemodHigh: Int {
    get { return _q.sync { __postDemodHigh } }
    set { _q.sync(flags: .barrier) { __postDemodHigh = newValue } } }
  
  internal var _postDemodLow: Int {
    get { return _q.sync { __postDemodLow } }
    set { _q.sync(flags: .barrier) { __postDemodLow = newValue } } }
  
  internal var _qskEnabled: Bool {
    get { return _q.sync { __qskEnabled } }
    set { _q.sync(flags: .barrier) { __qskEnabled = newValue } } }
  
  internal var _recordEnabled: Bool {
    get { return _q.sync { __recordEnabled } }
    set { _q.sync(flags: .barrier) { __recordEnabled = newValue } } }
  
  internal var _recordLength: Float {
    get { return _q.sync { __recordLength } }
    set { _q.sync(flags: .barrier) { __recordLength = newValue } } }
  
  internal var _repeaterOffsetDirection: String {
    get { return _q.sync { __repeaterOffsetDirection } }
    set { _q.sync(flags: .barrier) { __repeaterOffsetDirection = newValue } } }
  
  internal var _rfGain: Int {
    get { return _q.sync { __rfGain } }
    set { _q.sync(flags: .barrier) { __rfGain = newValue } } }
  
  internal var _ritEnabled: Bool {
    get { return _q.sync { __ritEnabled } }
    set { _q.sync(flags: .barrier) { __ritEnabled = newValue } } }
  
  internal var _ritOffset: Int {
    get { return _q.sync { __ritOffset } }
    set { _q.sync(flags: .barrier) { __ritOffset = newValue } } }
  
  internal var _rttyMark: Int {
    get { return _q.sync { __rttyMark } }
    set { _q.sync(flags: .barrier) { __rttyMark = newValue } } }
  
  internal var _rttyShift: Int {
    get { return _q.sync { __rttyShift } }
    set { _q.sync(flags: .barrier) { __rttyShift = newValue } } }
  
  internal var _rxAnt: Radio.AntennaPort {
    get { return _q.sync { __rxAnt } }
    set { _q.sync(flags: .barrier) { __rxAnt = newValue } } }
  
  internal var _rxAntList: [Radio.AntennaPort] {
    get { return _q.sync { __rxAntList } }
    set { _q.sync(flags: .barrier) { __rxAntList = newValue } } }
  
  internal var _step: Int {
    get { return _q.sync { __step } }
    set { _q.sync(flags: .barrier) { __step = newValue } } }
  
  internal var _stepList: String {
    get { return _q.sync { __stepList } }
    set { _q.sync(flags: .barrier) { __stepList = newValue } } }
  
  internal var _squelchEnabled: Bool {
    get { return _q.sync { __squelchEnabled } }
    set { _q.sync(flags: .barrier) { __squelchEnabled = newValue } } }
  
  internal var _squelchLevel: Int {
    get { return _q.sync { __squelchLevel } }
    set { _q.sync(flags: .barrier) { __squelchLevel = newValue } } }
  
  internal var _txAnt: String {
    get { return _q.sync { __txAnt } }
    set { _q.sync(flags: .barrier) { __txAnt = newValue } } }
  
  internal var _txAntList: [Radio.AntennaPort] {
    get { return _q.sync { __txAntList } }
    set { _q.sync(flags: .barrier) { __txAntList = newValue } } }
  
  internal var _txEnabled: Bool {
    get { return _q.sync { __txEnabled } }
    set { _q.sync(flags: .barrier) { __txEnabled = newValue } } }
  
  internal var _txOffsetFreq: Float {
    get { return _q.sync { __txOffsetFreq } }
    set { _q.sync(flags: .barrier) { __txOffsetFreq = newValue } } }
  
  internal var _wide: Bool {
    get { return _q.sync { __wide } }
    set { _q.sync(flags: .barrier) { __wide = newValue } } }
  
  internal var _wnbEnabled: Bool {
    get { return _q.sync { __wnbEnabled } }
    set { _q.sync(flags: .barrier) { __wnbEnabled = newValue } } }
  
  internal var _wnbLevel: Int {
    get { return _q.sync { __wnbLevel } }
    set { _q.sync(flags: .barrier) { __wnbLevel = newValue } } }
  
  internal var _xitEnabled: Bool {
    get { return _q.sync { __xitEnabled } }
    set { _q.sync(flags: .barrier) { __xitEnabled = newValue } } }
  
  internal var _xitOffset: Int {
    get { return _q.sync { __xitOffset } }
    set { _q.sync(flags: .barrier) { __xitOffset = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var autoPan: Bool {
    get { return _autoPan }
    set { if _autoPan != newValue { _autoPan = newValue } } }
  
  @objc dynamic public var daxClients: Int {
    get { return _daxClients }
    set { if _daxClients != newValue {  _daxClients = newValue } } }
  
  @objc dynamic public var daxTxEnabled: Bool {
    get { return _daxTxEnabled }
    set { if _daxTxEnabled != newValue { _daxTxEnabled = newValue } } }
  
  @objc dynamic public var diversityChild: Bool {
    get { return _diversityChild }
    set { if _diversityChild != newValue { if _diversityIsAllowed { _diversityChild = newValue } } } }
  
  @objc dynamic public var diversityIndex: Int {
    get { return _diversityIndex }
    set { if _diversityIndex != newValue { if _diversityIsAllowed { _diversityIndex = newValue } } } }
  
  @objc dynamic public var diversityParent: Bool {
    get { return _diversityParent }
    set { if _diversityParent != newValue { if _diversityIsAllowed { _diversityParent = newValue } } } }
  
  @objc dynamic public var inUse: Bool {
    return _inUse }
  
  @objc dynamic public var modeList: [String] {
    get { return _modeList }
    set { if _modeList != newValue { _modeList = newValue } } }
  
  @objc dynamic public var owner: Int {
    get { return _owner }
    set { if _owner != newValue { _owner = newValue } } }
  
  @objc dynamic public var panadapterId: PanadapterId {
    get { return _panadapterId }
    set {if _panadapterId != newValue {  _panadapterId = newValue } } }
  
  @objc dynamic public var postDemodBypassEnabled: Bool {
    get { return _postDemodBypassEnabled }
    set { if _postDemodBypassEnabled != newValue { _postDemodBypassEnabled = newValue } } }
  
  @objc dynamic public var postDemodHigh: Int {
    get { return _postDemodHigh }
    set { if _postDemodHigh != newValue { _postDemodHigh = newValue } } }
  
  @objc dynamic public var postDemodLow: Int {
    get { return _postDemodLow }
    set { if _postDemodLow != newValue { _postDemodLow = newValue } } }
  
  @objc dynamic public var qskEnabled: Bool {
    get { return _qskEnabled }
    set { if _qskEnabled != newValue { _qskEnabled = newValue } } }
  
  @objc dynamic public var recordLength: Float {
    get { return _recordLength }
    set { if _recordLength != newValue { _recordLength = newValue } } }
  
  @objc dynamic public var rxAntList: [Radio.AntennaPort] {
    get { return _rxAntList }
    set { _rxAntList = newValue } }
  
  @objc dynamic public var wide: Bool {
    get { return _wide }
    set { _wide = newValue } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var meters: [String: Meter] {                                               // meters
    get { return _meters }
    set { _meters = newValue } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Slice tokens
  
  internal enum Token : String {
    case active
    case agcMode                    = "agc_mode"
    case agcOffLevel                = "agc_off_level"
    case agcThreshold               = "agc_threshold"
    case anfEnabled                 = "anf"
    case anfLevel                   = "anf_level"
    case apfEnabled                 = "apf"
    case apfLevel                   = "apf_level"
    case audioGain                  = "audio_gain"
    case audioMute                  = "audio_mute"
    case audioPan                   = "audio_pan"
    case daxChannel                 = "dax"
    case daxClients                 = "dax_clients"
    case daxTxEnabled               = "dax_tx"
    case dfmPreDeEmphasisEnabled    = "dfm_pre_de_emphasis"
    case digitalLowerOffset         = "digl_offset"
    case digitalUpperOffset         = "digu_offset"
    case diversityEnabled           = "diversity"
    case diversityChild             = "diversity_child"
    case diversityIndex             = "diversity_index"
    case diversityParent            = "diversity_parent"
    case filterHigh                 = "filter_hi"
    case filterLow                  = "filter_lo"
    case fmDeviation                = "fm_deviation"
    case fmRepeaterOffset           = "fm_repeater_offset_freq"
    case fmToneBurstEnabled         = "fm_tone_burst"
    case fmToneMode                 = "fm_tone_mode"
    case fmToneFreq                 = "fm_tone_value"
    case frequency                  = "rf_frequency"
    case ghost
    case inUse                      = "in_use"
    case locked                     = "lock"
    case loopAEnabled               = "loopa"
    case loopBEnabled               = "loopb"
    case mode
    case modeList                   = "mode_list"
    case nbEnabled                  = "nb"
    case nbLevel                    = "nb_level"
    case nrEnabled                  = "nr"
    case nrLevel                    = "nr_level"
    case owner
    case panadapterId               = "pan"
    case playbackEnabled            = "play"
    case postDemodBypassEnabled     = "post_demod_bypass"
    case postDemodHigh              = "post_demod_high"
    case postDemodLow               = "post_demod_low"
    case qskEnabled                 = "qsk"
    case recordEnabled              = "record"
    case recordTime                 = "record_time"
    case repeaterOffsetDirection    = "repeater_offset_dir"
    case rfGain                     = "rfgain"
    case ritEnabled                 = "rit_on"
    case ritOffset                  = "rit_freq"
    case rttyMark                   = "rtty_mark"
    case rttyShift                  = "rtty_shift"
    case rxAnt                      = "rxant"
    case rxAntList                  = "ant_list"
    case squelchEnabled             = "squelch"
    case squelchLevel               = "squelch_level"
    case step
    case stepList                   = "step_list"
    case txEnabled                  = "tx"
    case txAnt                      = "txant"
    case txAntList                  = "tx_ant_list"
    case txOffsetFreq               = "tx_offset_freq"
    case wide
    case wnbEnabled                 = "wnb"
    case wnbLevel                   = "wnb_level"
    case xitEnabled                 = "xit_on"
    case xitOffset                  = "xit_freq"
  }
  
  // ----------------------------------------------------------------------------
  // Mark: - Other Slice related enums
  
  public enum RepeaterOffsetDirection : String {
    case up
    case down
    case simplex
  }
  
  public enum AgcMode : String {
    case off
    case slow
    case medium
    case fast
  }
  
  public enum Mode : String {
    case am
    case cw
    case dfm
    case digl
    case digu
    case dsb
    case dstr
    case fdv
    case fm
    case lsb
    case nfm
    case rtty
    case sam
    case usb
  }
  
}
