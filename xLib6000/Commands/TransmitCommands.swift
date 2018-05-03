//
//  TransmitCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Transmit Class extensions
//              - Dynamic public properties that send Commands to the Radio
//              - Internal methods
// --------------------------------------------------------------------------------

extension Transmit {
  
  //
  //  NOTE:   Transmit Commands are in one of the following formats:
  //
  //              transmit <valueName> <value>
  //              transmit set <valueName>=<value>
  //              cw <valueName> <value>
  //              mic <valueName>=<value>
  //
  
  // NOTE:    most outgoing commands use the same Token value as is found
  //          in the incoming Status messages, SOME DO NOT. The alternate
  //          form of the ...Cmd methods were created to deal with this issue.
  
  static let kTuneCmd                       = "transmit "                   // command prefixes
  static let kSetCmd                        = "transmit set "
  static let kCwCmd                         = "cw "
  static let kMicCmd                        = "mic "
  static let kMinPitch                      = 100
  static let kMaxPitch                      = 6_000
  static let kMinWpm                        = 5
  static let kMaxWpm                        = 100
  static let kMinDelay                      = 0
  static let kMaxDelay                      = 2_000
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set the Tune property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func tuneCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Transmit.kTuneCmd + token.rawValue + " \(value)")
  }
  /// Set a Transmit property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func transmitCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Transmit.kSetCmd + token.rawValue + "=\(value)")
  }
  // alternate form for commands that do not use the Token raw value in outgoing messages
  private func transmitCmd(_ token: String, _ value: Any) {
    
    Api.sharedInstance.send(Transmit.kSetCmd + token + "=\(value)")
  }
  /// Set a CW property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func cwCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Transmit.kCwCmd + token.rawValue + " \(value)")
  }
  // alternate form for commands that do not use the Token raw value in outgoing messages
  private func cwCmd(_ token: String, _ value: Any) {
    
    Api.sharedInstance.send(Transmit.kCwCmd + token + " \(value)")
  }
  
  /// Set a MIC property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func micCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Transmit.kMicCmd + token.rawValue + "=\(value)")
  }
  // alternate form for commands that do not use the Token raw value in outgoing messages
  private func micCmd(_ token: String, _ value: Any) {
    
    Api.sharedInstance.send(Transmit.kMicCmd + token + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // ***** CW COMMANDS *****
  
  @objc dynamic public var cwBreakInDelay: Int {
    get {  return _cwBreakInDelay }
    set { if _cwBreakInDelay != newValue { _cwBreakInDelay = newValue.bound(Transmit.kMinDelay, Transmit.kMaxDelay) ; cwCmd( .cwBreakInDelay, newValue) } } }
  
  @objc dynamic public var cwBreakInEnabled: Bool {
    get {  return _cwBreakInEnabled }
    set { if _cwBreakInEnabled != newValue { _cwBreakInEnabled = newValue ; cwCmd( .cwBreakInEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var cwIambicEnabled: Bool {
    get {  return _cwIambicEnabled }
    set { if _cwIambicEnabled != newValue { _cwIambicEnabled = newValue ; cwCmd( .cwIambicEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var cwIambicMode: Int {
    get {  return _cwIambicMode }
    set { if _cwIambicMode != newValue { _cwIambicMode = newValue ; cwCmd( "mode", newValue) } } }
  
  @objc dynamic public var cwlEnabled: Bool {
    get {  return _cwlEnabled }
    set { if _cwlEnabled != newValue { _cwlEnabled = newValue ; cwCmd( .cwlEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var cwPitch: Int {
    get {  return _cwPitch }
    set { if _cwPitch != newValue { _cwPitch = newValue.bound(Transmit.kMinPitch, Transmit.kMaxPitch) ; cwCmd( .cwPitch, newValue) } } }
  
  @objc dynamic public var cwSidetoneEnabled: Bool {
    get {  return _cwSidetoneEnabled }
    set { if _cwSidetoneEnabled != newValue { _cwSidetoneEnabled = newValue ; cwCmd( .cwSidetoneEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var cwSpeed: Int {
    get {  return _cwSpeed }
    set { if _cwSpeed != newValue { _cwSpeed = newValue.bound(Transmit.kMinWpm, Transmit.kMaxWpm) ; cwCmd( "wpm", newValue) } } }
  
  @objc dynamic public var cwSwapPaddles: Bool {
    get {  return _cwSwapPaddles }
    set { if _cwSwapPaddles != newValue { _cwSwapPaddles = newValue ; cwCmd( "swap", newValue.asNumber()) } } }
  
  @objc dynamic public var cwSyncCwxEnabled: Bool {
    get {  return _cwSyncCwxEnabled }
    set { if _cwSyncCwxEnabled != newValue { _cwSyncCwxEnabled = newValue ; cwCmd( .cwSyncCwxEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var cwWeight: Int {
    get {  return _cwWeight }
    set { if _cwWeight != newValue { _cwWeight = newValue ; cwCmd( "weight", newValue) } } }
  
  // ***** MIC COMMANDS *****
  
  @objc dynamic public var micAccEnabled: Bool {
    get {  return _micAccEnabled }
    set { if _micAccEnabled != newValue { _micAccEnabled = newValue ; micCmd( "acc", newValue.asNumber()) } } }
  
  @objc dynamic public var micBiasEnabled: Bool {
    get {  return _micBiasEnabled }
    set { if _micBiasEnabled != newValue { _micBiasEnabled = newValue ; micCmd( "bias", newValue.asNumber()) } } }
  
  @objc dynamic public var micBoostEnabled: Bool {
    get {  return _micBoostEnabled }
    set { if _micBoostEnabled != newValue { _micBoostEnabled = newValue ; micCmd( "boost", newValue.asNumber()) } } }
  
  @objc dynamic public var micSelection: String {
    get {  return _micSelection }
    set { if _micSelection != newValue { _micSelection = newValue ; micCmd( "input", newValue) } } }
  
  // ***** TRANSMIT COMMANDS *****
  
  @objc dynamic public var carrierLevel: Int {
    get {  return _carrierLevel }
    set { if _carrierLevel != newValue { _carrierLevel = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( "am_carrier", newValue) } } }
  
  @objc dynamic public var companderEnabled: Bool {
    get {  return _companderEnabled }
    set { if _companderEnabled != newValue { _companderEnabled = newValue ; transmitCmd( .companderEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var companderLevel: Int {
    get {  return _companderLevel }
    set { if _companderLevel != newValue { _companderLevel = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .companderLevel, newValue) } } }
  
  @objc dynamic public var cwAutoSpaceEnabled: Bool {
    get {  return _cwAutoSpaceEnabled }
    set { if _cwAutoSpaceEnabled != newValue { _cwAutoSpaceEnabled = newValue ; transmitCmd( "auto_space", newValue.asNumber()) } } }
  
  @objc dynamic public var daxEnabled: Bool {
    get {  return _daxEnabled }
    set { if _daxEnabled != newValue { _daxEnabled = newValue ; transmitCmd( .daxEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var hwAlcEnabled: Bool {
    get {  return _hwAlcEnabled }
    set { if _hwAlcEnabled != newValue { _hwAlcEnabled = newValue ; transmitCmd( .hwAlcEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var inhibit: Bool {
    get {  return _inhibit }
    set { if _inhibit != newValue { _inhibit = newValue ; transmitCmd( .inhibit, newValue.asNumber()) } } }
  
  @objc dynamic public var maxPowerLevel: Int {
    get {  return _maxPowerLevel }
    set { if _maxPowerLevel != newValue { _maxPowerLevel = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .maxPowerLevel, newValue) } } }
  
  @objc dynamic public var metInRxEnabled: Bool {
    get {  return _metInRxEnabled }
    set { if _metInRxEnabled != newValue { _metInRxEnabled = newValue ; transmitCmd( .metInRxEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var micLevel: Int {
    get {  return _micLevel }
    set { if _micLevel != newValue { _micLevel = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( "miclevel", newValue) } } }
  
  @objc dynamic public var moxEnabled: Bool {
    get { return _moxEnabled }
    set { if _moxEnabled != newValue { _moxEnabled = newValue ; transmitCmd( "mox", newValue.asNumber()) } } }
  
  @objc dynamic public var rfPower: Int {
    get {  return _rfPower }
    set { if _rfPower != newValue { _rfPower = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .rfPower, newValue) } } }
  
  @objc dynamic public var speechProcessorEnabled: Bool {
    get {  return _speechProcessorEnabled }
    set { if _speechProcessorEnabled != newValue { _speechProcessorEnabled = newValue ; transmitCmd( .speechProcessorEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var speechProcessorLevel: Int {
    get {  return _speechProcessorLevel }
    set { if _speechProcessorLevel != newValue { _speechProcessorLevel = newValue ; transmitCmd( .speechProcessorLevel, newValue) } } }
  
  @objc dynamic public var ssbPeakControlEnabled: Bool {
    get {  return _ssbPeakControlEnabled }
    set { if _ssbPeakControlEnabled != newValue { _ssbPeakControlEnabled = newValue ; transmitCmd("ssb_peak_control", newValue.asNumber()) } } }
  
  @objc dynamic public var tunePower: Int {
    get {  return _tunePower }
    set { if _tunePower != newValue { _tunePower = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .tunePower, newValue) } } }
  
  @objc dynamic public var txFilterHigh: Int {
    get { return _txFilterHigh }
    set { if _txFilterHigh != newValue { let value = txFilterHighLimits(txFilterLow, newValue) ; _txFilterHigh = value ; transmitCmd( "filter_high", value) } } }
  
  @objc dynamic public var txFilterLow: Int {
    get { return _txFilterLow }
    set { if _txFilterLow != newValue { let value = txFilterLowLimits(newValue, txFilterHigh) ; _txFilterLow = value ; transmitCmd( "filter_low", value) } } }
  
  @objc dynamic public var txInWaterfallEnabled: Bool {
    get { return _txInWaterfallEnabled }
    set { if _txInWaterfallEnabled != newValue { _txInWaterfallEnabled = newValue ; transmitCmd( .txInWaterfallEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var txMonitorEnabled: Bool {
    get {  return _txMonitorEnabled }
    set { if _txMonitorEnabled != newValue { _txMonitorEnabled = newValue ; transmitCmd( "mon", newValue.asNumber()) } } }
  
  @objc dynamic public var txMonitorGainCw: Int {
    get {  return _txMonitorGainCw }
    set { if _txMonitorGainCw != newValue { _txMonitorGainCw = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .txMonitorGainCw, newValue) } } }
  
  @objc dynamic public var txMonitorGainSb: Int {
    get {  return _txMonitorGainSb }
    set { if _txMonitorGainSb != newValue { _txMonitorGainSb = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .txMonitorGainSb, newValue) } } }
  
  @objc dynamic public var txMonitorPanCw: Int {
    get {  return _txMonitorPanCw }
    set { if _txMonitorPanCw != newValue { _txMonitorPanCw = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .txMonitorPanCw, newValue) } } }
  
  @objc dynamic public var txMonitorPanSb: Int {
    get {  return _txMonitorPanSb }
    set { if _txMonitorPanSb != newValue { _txMonitorPanSb = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .txMonitorPanSb, newValue) } } }
  
  @objc dynamic public var voxEnabled: Bool {
    get { return _voxEnabled }
    set { if _voxEnabled != newValue { _voxEnabled = newValue ; transmitCmd( .voxEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var voxDelay: Int {
    get { return _voxDelay }
    set { if _voxDelay != newValue { _voxDelay = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .voxDelay, newValue) } } }
  
  @objc dynamic public var voxLevel: Int {
    get { return _voxLevel }
    set { if _voxLevel != newValue { _voxLevel = newValue.bound(Radio.kMin, Radio.kMax) ; transmitCmd( .voxLevel, newValue) } } }
  
  // ***** TUNE COMMANDS *****
  
  @objc dynamic public var tune: Bool {
    get {  return _tune }
    set { if _tune != newValue { _tune = newValue ; tuneCmd( .tune, newValue.asNumber()) } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func txFilterHighLimits(_ low: Int, _ high: Int) -> Int {
    
    let newValue = ( high < low + 50 ? low + 50 : high )
    return newValue > 10_000 ? 10_000 : newValue
  }
  func txFilterLowLimits(_ low: Int, _ high: Int) -> Int {
    
    let newValue = ( low > high - 50 ? high - 50 : low )
    return newValue < 0 ? 0 : newValue
  }
  
}
