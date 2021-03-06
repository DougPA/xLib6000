//
//  Transmit.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Transmit Class implementation
//
//      creates a Transmit instance to be used by a Client to support the
//      processing of the Transmit-related activities. Transmit objects are added,
//      removed and updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Transmit                 : NSObject, StaticModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __carrierLevel                = 0                             //
  private var __companderEnabled            = false                         //
  private var __companderLevel              = 0                             //
  private var __cwAutoSpaceEnabled          = false                         //
  private var __cwBreakInDelay              = 0                             //
  private var __cwBreakInEnabled            = false                         //
  private var __cwIambicEnabled             = false                         //
  private var __cwIambicMode                = 0                             //
  private var __cwlEnabled                  = false                         //
  private var __cwPitch                     = 0                             // CW pitch frequency (Hz)
  private var __cwSidetoneEnabled           = false                         //
  private var __cwSwapPaddles               = false                         //
  private var __cwSyncCwxEnabled            = false                         //
  private var __cwWeight                    = 0                             // CW weight (0 - 100)
  private var __cwSpeed                     = 5                             // CW speed (wpm, 5 - 100)
  private var __daxEnabled                  = false                         // Dax enabled
  private var __frequency                   = 0                             //
  private var __hwAlcEnabled                = false                         //
  private var __inhibit                     = false                         //
  private var __maxPowerLevel               = 0                             //
  private var __metInRxEnabled              = false                         //
  private var __micAccEnabled               = false                         //
  private var __micBiasEnabled              = false                         //
  private var __micBoostEnabled             = false                         //
  private var __micLevel                    = 0                             //
  private var __micSelection                = ""                            //
  private var __rawIqEnabled                = false                         //
  private var __rfPower                     = 0                             // Power level (0 - 100)
  private var __speechProcessorEnabled      = false                         //
  private var __speechProcessorLevel        = 0                             //
  private var __ssbPeakControlEnabled       = false                         //
  private var __txFilterChanges             = false                         //
  private var __txFilterHigh                = 0                             //
  private var __txFilterLow                 = 0                             //
  private var __txInWaterfallEnabled        = false                         //
  private var __txMonitorAvailable          = false                         //
  private var __txMonitorEnabled            = false                         //
  private var __txMonitorGainCw             = 0                             //
  private var __txMonitorGainSb             = 0                             //
  private var __txMonitorPanCw              = 0                             //
  private var __txMonitorPanSb              = 0                             //
  private var __txRfPowerChanges            = false                         //
  private var __tune                        = false                         //
  private var __tunePower                   = 0                             //
  private var __voxDelay                    = 0                             // VOX delay (seconds?)
  private var __voxEnabled                  = false                         // VOX enabled
  private var __voxLevel                    = 0                             // VOX level ( ?? - ??)
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Transmit
  ///
  /// - Parameters:
  ///   - queue:              Concurrent queue
  ///
  public init(queue: DispatchQueue) {
    self._q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse a Transmit status message
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = Token(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .amCarrierLevel:
        willChangeValue(for: \.carrierLevel)
        _carrierLevel = property.value.iValue()
        didChangeValue(for: \.carrierLevel)

      case .companderEnabled:
        willChangeValue(for: \.companderEnabled)
        _companderEnabled = property.value.bValue()
        didChangeValue(for: \.companderEnabled)

      case .companderLevel:
        willChangeValue(for: \.companderLevel)
        _companderLevel = property.value.iValue()
        didChangeValue(for: \.companderLevel)

      case .cwBreakInEnabled:
        willChangeValue(for: \.cwBreakInEnabled)
        _cwBreakInEnabled = property.value.bValue()
        didChangeValue(for: \.cwBreakInEnabled)

      case .cwBreakInDelay:
        willChangeValue(for: \.cwBreakInDelay)
        _cwBreakInDelay = property.value.iValue()
        didChangeValue(for: \.cwBreakInDelay)

      case .cwIambicEnabled:
        willChangeValue(for: \.cwIambicEnabled)
        _cwIambicEnabled = property.value.bValue()
        didChangeValue(for: \.cwIambicEnabled)

      case .cwIambicMode:
        willChangeValue(for: \.cwIambicMode)
        _cwIambicMode = property.value.iValue()
        didChangeValue(for: \.cwIambicMode)

      case .cwlEnabled:
        willChangeValue(for: \.cwlEnabled)
        _cwlEnabled = property.value.bValue()
        didChangeValue(for: \.cwlEnabled)

      case .cwPitch:
        willChangeValue(for: \.cwPitch)
        _cwPitch = property.value.iValue()
        didChangeValue(for: \.cwPitch)

      case .cwSidetoneEnabled:
        willChangeValue(for: \.cwSidetoneEnabled)
        _cwSidetoneEnabled = property.value.bValue()
        didChangeValue(for: \.cwSidetoneEnabled)

      case .cwSpeed:
        willChangeValue(for: \.cwSpeed)
        _cwSpeed = property.value.iValue()
        didChangeValue(for: \.cwSpeed)

      case .cwSwapPaddles:
        willChangeValue(for: \.cwSwapPaddles)
        _cwSwapPaddles = property.value.bValue()
        didChangeValue(for: \.cwSwapPaddles)

      case .cwSyncCwxEnabled:
        willChangeValue(for: \.cwSyncCwxEnabled)
        _cwSyncCwxEnabled = property.value.bValue()
        didChangeValue(for: \.cwSyncCwxEnabled)

      case .daxEnabled:
        willChangeValue(for: \.daxEnabled)
        _daxEnabled = property.value.bValue()
        didChangeValue(for: \.daxEnabled)

      case .frequency:
        willChangeValue(for: \.frequency)
        _frequency = property.value.mhzToHz()
        didChangeValue(for: \.frequency)

      case .hwAlcEnabled:
        willChangeValue(for: \.hwAlcEnabled)
        _hwAlcEnabled = property.value.bValue()
        didChangeValue(for: \.hwAlcEnabled)

      case .inhibit:
        willChangeValue(for: \.inhibit)
        _inhibit = property.value.bValue()
        didChangeValue(for: \.inhibit)

      case .maxPowerLevel:
        willChangeValue(for: \.maxPowerLevel)
        _maxPowerLevel = property.value.iValue()
        didChangeValue(for: \.maxPowerLevel)

      case .metInRxEnabled:
        willChangeValue(for: \.metInRxEnabled)
        _metInRxEnabled = property.value.bValue()
        didChangeValue(for: \.metInRxEnabled)

      case .micAccEnabled:
        willChangeValue(for: \.micAccEnabled)
        _micAccEnabled = property.value.bValue()
        didChangeValue(for: \.micAccEnabled)

      case .micBoostEnabled:
        willChangeValue(for: \.micBoostEnabled)
        _micBoostEnabled = property.value.bValue()
        didChangeValue(for: \.micBoostEnabled)

      case .micBiasEnabled:
        willChangeValue(for: \.micBiasEnabled)
        _micBiasEnabled = property.value.bValue()
        didChangeValue(for: \.micBiasEnabled)

      case .micLevel:
        willChangeValue(for: \.micLevel)
        _micLevel = property.value.iValue()
        didChangeValue(for: \.micLevel)

      case .micSelection:
        willChangeValue(for: \.micSelection)
        _micSelection = property.value
        didChangeValue(for: \.micSelection)

      case .rawIqEnabled:
        willChangeValue(for: \.rawIqEnabled)
        _rawIqEnabled = property.value.bValue()
        didChangeValue(for: \.rawIqEnabled)

      case .rfPower:
        willChangeValue(for: \.rfPower)
        _rfPower = property.value.iValue()
        didChangeValue(for: \.rfPower)

      case .speechProcessorEnabled:
        willChangeValue(for: \.speechProcessorEnabled)
        _speechProcessorEnabled = property.value.bValue()
        didChangeValue(for: \.speechProcessorEnabled)

      case .speechProcessorLevel:
        willChangeValue(for: \.speechProcessorLevel)
        _speechProcessorLevel = property.value.iValue()
        didChangeValue(for: \.speechProcessorLevel)

      case .txFilterChanges:
        willChangeValue(for: \.txFilterChanges)
        _txFilterChanges = property.value.bValue()
        didChangeValue(for: \.txFilterChanges)

      case .txFilterHigh:
        willChangeValue(for: \.txFilterHigh)
        _txFilterHigh = property.value.iValue()
        didChangeValue(for: \.txFilterHigh)

      case .txFilterLow:
        willChangeValue(for: \.txFilterLow)
        _txFilterLow = property.value.iValue()
        didChangeValue(for: \.txFilterLow)

      case .txInWaterfallEnabled:
        willChangeValue(for: \.txInWaterfallEnabled)
        _txInWaterfallEnabled = property.value.bValue()
        didChangeValue(for: \.txInWaterfallEnabled)

      case .txMonitorAvailable:
        willChangeValue(for: \.txMonitorAvailable)
        _txMonitorAvailable = property.value.bValue()
        didChangeValue(for: \.txMonitorAvailable)

      case .txMonitorEnabled:
        willChangeValue(for: \.txMonitorEnabled)
        _txMonitorEnabled = property.value.bValue()
        didChangeValue(for: \.txMonitorEnabled)

      case .txMonitorGainCw:
        willChangeValue(for: \.txMonitorGainCw)
        _txMonitorGainCw = property.value.iValue()
        didChangeValue(for: \.txMonitorGainCw)

      case .txMonitorGainSb:
        willChangeValue(for: \.txMonitorGainSb)
        _txMonitorGainSb = property.value.iValue()
        didChangeValue(for: \.txMonitorGainSb)

      case .txMonitorPanCw:
        willChangeValue(for: \.txMonitorPanCw)
        _txMonitorPanCw = property.value.iValue()
        didChangeValue(for: \.txMonitorPanCw)

      case .txMonitorPanSb:
        willChangeValue(for: \.txMonitorPanSb)
        _txMonitorPanSb = property.value.iValue()
        didChangeValue(for: \.txMonitorPanSb)

      case .txRfPowerChanges:
        willChangeValue(for: \.txRfPowerChanges)
        _txRfPowerChanges = property.value.bValue()
        didChangeValue(for: \.txRfPowerChanges)

      case .tune:
        willChangeValue(for: \.tune)
        _tune = property.value.bValue()
        didChangeValue(for: \.tune)

      case .tunePower:
        willChangeValue(for: \.tunePower)
        _tunePower = property.value.iValue()
        didChangeValue(for: \.tunePower)

      case .voxEnabled:
        willChangeValue(for: \.voxEnabled)
        _voxEnabled = property.value.bValue()
        didChangeValue(for: \.voxEnabled)

      case .voxDelay:
        willChangeValue(for: \.voxDelay)
        _voxDelay = property.value.iValue()
        didChangeValue(for: \.voxDelay)

      case .voxLevel:
        willChangeValue(for: \.voxLevel)
        _voxLevel = property.value.iValue()
        didChangeValue(for: \.voxLevel)
      }
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Transmit Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Transmit tokens
// --------------------------------------------------------------------------------

extension Transmit {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _carrierLevel: Int {
    get { return _q.sync { __carrierLevel } }
    set { _q.sync(flags: .barrier) { __carrierLevel = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _companderEnabled: Bool {
    get { return _q.sync { __companderEnabled } }
    set { _q.sync(flags: .barrier) { __companderEnabled = newValue } } }
  
  internal var _companderLevel: Int {
    get { return _q.sync { __companderLevel } }
    set { _q.sync(flags: .barrier) { __companderLevel = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _cwAutoSpaceEnabled: Bool {
    get { return _q.sync { __cwAutoSpaceEnabled } }
    set { _q.sync(flags: .barrier) { __cwAutoSpaceEnabled = newValue } } }
  
  internal var _cwBreakInEnabled: Bool {
    get { return _q.sync { __cwBreakInEnabled } }
    set { _q.sync(flags: .barrier) { __cwBreakInEnabled = newValue } } }
  
  internal var _cwBreakInDelay: Int {
    get { return _q.sync { __cwBreakInDelay } }
    set { _q.sync(flags: .barrier) { __cwBreakInDelay = newValue.bound(Transmit.kMinDelay, Transmit.kMaxDelay) } } }
  
  internal var _cwIambicEnabled: Bool {
    get { return _q.sync { __cwIambicEnabled } }
    set { _q.sync(flags: .barrier) { __cwIambicEnabled = newValue } } }
  
  internal var _cwIambicMode: Int {
    get { return _q.sync { __cwIambicMode } }
    set { _q.sync(flags: .barrier) { __cwIambicMode = newValue } } }
  
  internal var _cwlEnabled: Bool {
    get { return _q.sync { __cwlEnabled } }
    set { _q.sync(flags: .barrier) { __cwlEnabled = newValue } } }
  
  internal var _cwPitch: Int {
    get { return _q.sync { __cwPitch } }
    set { _q.sync(flags: .barrier) { __cwPitch = newValue.bound(Transmit.kMinPitch, Transmit.kMaxPitch) } } }
  
  internal var _cwSidetoneEnabled: Bool {
    get { return _q.sync { __cwSidetoneEnabled } }
    set { _q.sync(flags: .barrier) { __cwSidetoneEnabled = newValue } } }
  
  internal var _cwSwapPaddles: Bool {
    get { return _q.sync { __cwSwapPaddles } }
    set { _q.sync(flags: .barrier) { __cwSwapPaddles = newValue } } }
  
  internal var _cwSyncCwxEnabled: Bool {
    get { return _q.sync { __cwSyncCwxEnabled } }
    set { _q.sync(flags: .barrier) { __cwSyncCwxEnabled = newValue } } }
  
  internal var _cwWeight: Int {
    get { return _q.sync { __cwWeight } }
    set { _q.sync(flags: .barrier) { __cwWeight = newValue } } }
  
  internal var _cwSpeed: Int {
    get { return _q.sync { __cwSpeed } }
    set { _q.sync(flags: .barrier) { __cwSpeed = newValue.bound(Transmit.kMinWpm, Transmit.kMaxWpm) } } }
  
  internal var _daxEnabled: Bool {
    get { return _q.sync { __daxEnabled } }
    set { _q.sync(flags: .barrier) { __daxEnabled = newValue } } }
  
  internal var _frequency: Int {
    get { return _q.sync { __frequency } }
    set { _q.sync(flags: .barrier) { __frequency = newValue } } }
  
  internal var _hwAlcEnabled: Bool {
    get { return _q.sync { __hwAlcEnabled } }
    set { _q.sync(flags: .barrier) { __hwAlcEnabled = newValue } } }
  
  internal var _inhibit: Bool {
    get { return _q.sync { __inhibit } }
    set { _q.sync(flags: .barrier) { __inhibit = newValue } } }
  
  internal var _maxPowerLevel: Int {
    get { return _q.sync { __maxPowerLevel } }
    set { _q.sync(flags: .barrier) { __maxPowerLevel = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _metInRxEnabled: Bool {
    get { return _q.sync { __metInRxEnabled } }
    set { _q.sync(flags: .barrier) { __metInRxEnabled = newValue } } }
  
  internal var _micAccEnabled: Bool {
    get { return _q.sync { __micAccEnabled } }
    set { _q.sync(flags: .barrier) { __micAccEnabled = newValue } } }
  
  internal var _micBoostEnabled: Bool {
    get { return _q.sync { __micBoostEnabled } }
    set { _q.sync(flags: .barrier) { __micBoostEnabled = newValue } } }
  
  internal var _micBiasEnabled: Bool {
    get { return _q.sync { __micBiasEnabled } }
    set { _q.sync(flags: .barrier) { __micBiasEnabled = newValue } } }
  
  internal var _micLevel: Int {
    get { return _q.sync { __micLevel } }
    set { _q.sync(flags: .barrier) { __micLevel = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _micSelection: String {
    get { return _q.sync { __micSelection } }
    set { _q.sync(flags: .barrier) { __micSelection = newValue } } }
  
  internal var _rawIqEnabled: Bool {
    get { return _q.sync { __rawIqEnabled } }
    set { _q.sync(flags: .barrier) { __rawIqEnabled = newValue } } }
  
  internal var _rfPower: Int {
    get { return _q.sync { __rfPower } }
    set { _q.sync(flags: .barrier) { __rfPower = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _speechProcessorEnabled: Bool {
    get { return _q.sync { __speechProcessorEnabled } }
    set { _q.sync(flags: .barrier) { __speechProcessorEnabled = newValue } } }
  
  internal var _speechProcessorLevel: Int {
    get { return _q.sync { __speechProcessorLevel } }
    set { _q.sync(flags: .barrier) { __speechProcessorLevel = newValue } } }
  
  internal var _ssbPeakControlEnabled: Bool {
    get { return _q.sync { __ssbPeakControlEnabled } }
    set { _q.sync(flags: .barrier) { __ssbPeakControlEnabled = newValue } } }
  
  internal var _txFilterChanges: Bool {
    get { return _q.sync { __txFilterChanges } }
    set { _q.sync(flags: .barrier) { __txFilterChanges = newValue } } }
  
  internal var _txFilterHigh: Int {
    get { return _q.sync { __txFilterHigh } }
    set { let value = txFilterHighLimits(txFilterLow, newValue) ; _q.sync(flags: .barrier) { __txFilterHigh = value } } }
  
  internal var _txFilterLow: Int {
    get { return _q.sync { __txFilterLow } }
    set { let value = txFilterLowLimits(newValue, txFilterHigh) ; _q.sync(flags: .barrier) { __txFilterLow = value } } }
  
  internal var _txInWaterfallEnabled: Bool {
    get { return _q.sync { __txInWaterfallEnabled } }
    set { _q.sync(flags: .barrier) { __txInWaterfallEnabled = newValue } } }
  
  internal var _txMonitorAvailable: Bool {
    get { return _q.sync { __txMonitorAvailable } }
    set { _q.sync(flags: .barrier) { __txMonitorAvailable = newValue } } }
  
  internal var _txMonitorEnabled: Bool {
    get { return _q.sync { __txMonitorEnabled } }
    set { _q.sync(flags: .barrier) { __txMonitorEnabled = newValue } } }
  
  internal var _txMonitorGainCw: Int {
    get { return _q.sync { __txMonitorGainCw } }
    set { _q.sync(flags: .barrier) { __txMonitorGainCw = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _txMonitorGainSb: Int {
    get { return _q.sync { __txMonitorGainSb } }
    set { _q.sync(flags: .barrier) { __txMonitorGainSb = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _txMonitorPanCw: Int {
    get { return _q.sync { __txMonitorPanCw } }
    set { _q.sync(flags: .barrier) { __txMonitorPanCw = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _txMonitorPanSb: Int {
    get { return _q.sync { __txMonitorPanSb } }
    set { _q.sync(flags: .barrier) { __txMonitorPanSb = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _txRfPowerChanges: Bool {
    get { return _q.sync { __txRfPowerChanges } }
    set { _q.sync(flags: .barrier) { __txRfPowerChanges = newValue } } }
  
  internal var _tune: Bool {
    get { return _q.sync { __tune } }
    set { _q.sync(flags: .barrier) { __tune = newValue } } }
  
  internal var _tunePower: Int {
    get { return _q.sync { __tunePower } }
    set { _q.sync(flags: .barrier) { __tunePower = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _voxEnabled: Bool {
    get { return _q.sync { __voxEnabled } }
    set { _q.sync(flags: .barrier) { __voxEnabled = newValue } } }
  
  internal var _voxDelay: Int {
    get { return _q.sync { __voxDelay } }
    set { _q.sync(flags: .barrier) { __voxDelay = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  internal var _voxLevel: Int {
    get { return _q.sync { __voxLevel } }
    set { _q.sync(flags: .barrier) { __voxLevel = newValue.bound(Api.kControlMin, Api.kControlMax) } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  @objc dynamic public var frequency: Int {
    get {  return _frequency }
    set { if _frequency != newValue { _frequency = newValue } } }
  
  @objc dynamic public var rawIqEnabled: Bool {
    return _rawIqEnabled }
  
  @objc dynamic public var txFilterChanges: Bool {
    return _txFilterChanges }
  
  @objc dynamic public var txMonitorAvailable: Bool {
    return _txMonitorAvailable }
  
  @objc dynamic public var txRfPowerChanges: Bool {
    return _txRfPowerChanges }
  
  // ----------------------------------------------------------------------------
  // MARK: - Transmit tokens
  
  internal enum Token: String {
    case amCarrierLevel           = "am_carrier_level"
    case companderEnabled         = "compander"
    case companderLevel           = "compander_level"
    case cwBreakInDelay           = "break_in_delay"
    case cwBreakInEnabled         = "break_in"
    case cwIambicEnabled          = "iambic"
    case cwIambicMode             = "iambic_mode"
    case cwlEnabled               = "cwl_enabled"
    case cwPitch                  = "pitch"
    case cwSidetoneEnabled        = "sidetone"
    case cwSpeed                  = "speed"
    case cwSwapPaddles            = "swap_paddles"
    case cwSyncCwxEnabled         = "synccwx"
    case daxEnabled               = "dax"
    case frequency                = "freq"
    case hwAlcEnabled             = "hwalc_enabled"
    case inhibit
    case maxPowerLevel            = "max_power_level"
    case metInRxEnabled           = "met_in_rx"
    case micAccEnabled            = "mic_acc"
    case micBoostEnabled          = "mic_boost"
    case micBiasEnabled           = "mic_bias"
    case micLevel                 = "mic_level"
    case micSelection             = "mic_selection"
    case rawIqEnabled             = "raw_iq_enable"
    case rfPower                  = "rfpower"
    case speechProcessorEnabled   = "speech_processor_enable"
    case speechProcessorLevel     = "speech_processor_level"
    case tune
    case tunePower                = "tunepower"
    case txFilterChanges          = "tx_filter_changes_allowed"
    case txFilterHigh             = "hi"
    case txFilterLow              = "lo"
    case txInWaterfallEnabled     = "show_tx_in_waterfall"
    case txMonitorAvailable       = "mon_available"
    case txMonitorEnabled         = "sb_monitor"
    case txMonitorGainCw          = "mon_gain_cw"
    case txMonitorGainSb          = "mon_gain_sb"
    case txMonitorPanCw           = "mon_pan_cw"
    case txMonitorPanSb           = "mon_pan_sb"
    case txRfPowerChanges         = "tx_rf_power_changes_allowed"
    case voxEnabled               = "vox_enable"
    case voxDelay                 = "vox_delay"
    case voxLevel                 = "vox_level"
  }
}
