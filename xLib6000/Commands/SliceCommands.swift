//
//  SliceCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Slice Class extensions
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension xLib6000.Slice {
  
  // NOTE:    most outgoing commands use the same Token value as is found
  //          in the incoming Status messages, SOME DO NOT. The alternate
  //          form of the ...Cmd methods were created to deal with this issue.
  
  static let kCreateCmd                     = "slice create "               // Command prefixes
  static let kRemoveCmd                     = "slice remove "
  static let kCmd                           = "slice "
  static let kSetCmd                        = "slice set "
  static let kTuneCmd                       = "slice tune "
  static let kAudioCmd                      = "audio client 0 slice "
  static let kFilterCmd                     = "filt "
  static let kListCmd                       = "slice list"

  static let kMinOffset                     = -99_999                       // frequency offset range
  static let kMaxOffset                     = 99_999
  
  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands to the Radio (hardware)
  
  /// Create a new Slice
  ///
  /// - Parameters:
  ///   - frequency:          frequenct (Hz)
  ///   - antenna:            selected antenna
  ///   - mode:               selected mode
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func create(frequency: Int, antenna: String, mode: String, callback: ReplyHandler? = nil) { if Api.sharedInstance.radio!.availableSlices > 0 {
    
    // tell the Radio to create a Slice
    Api.sharedInstance.send(xLib6000.Slice.kCreateCmd + "\(frequency.hzToMhz()) \(antenna) \(mode)", replyTo: callback) }
  }
  /// Create a new Slice
  ///
  /// - Parameters:
  ///   - panadapter:         selected panadapter
  ///   - frequency:          frequency (Hz)
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func create(panadapter: Panadapter, frequency: Int = 0, callback: ReplyHandler? = nil) { if Api.sharedInstance.radio!.availableSlices > 0 {
    
    // tell the Radio to create a Slice
    Api.sharedInstance.send(xLib6000.Slice.kCreateCmd + "pan" + "=\(panadapter.id.hex) \(frequency == 0 ? "" : "freq" + "=\(frequency.hzToMhz())")", replyTo: callback) }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send Commands to the Radio (hardware)
  
  /// Remove this Slice
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove a Slice
    Api.sharedInstance.send(xLib6000.Slice.kRemoveCmd + " \(id)", replyTo: callback)
  }
  /// Requent the Slice frequency error values
  ///
  /// - Parameters:
  ///   - id:                 Slice Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func errorRequest(_ id: SliceId, callback: ReplyHandler? = nil) {
    
    // ask the Radio for the current frequency error
    Api.sharedInstance.send(xLib6000.Slice.kCmd + "get_error" + " \(id)", replyTo: callback == nil ? Api.sharedInstance.radio!.defaultReplyHandler : callback)
  }
  /// Request a list of slice Stream Id's
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func listRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio for a list of Slices
    Api.sharedInstance.send(xLib6000.Slice.kCmd + "list", replyTo: callback == nil ? Api.sharedInstance.radio!.defaultReplyHandler : callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a Slice tune property on the Radio
  ///
  /// - Parameters:
  ///   - value:      the new value
  ///
  private func sliceTuneCmd(_ value: Any) {
    
    Api.sharedInstance.send(xLib6000.Slice.kTuneCmd + "0x\(id) \(value) autopan=\(_autoPan.asNumber())")
  }
  /// Set a Slice Lock property on the Radio
  ///
  /// - Parameters:
  ///   - value:      the new value (lock / unlock)
  ///
  private func sliceLock(_ value: String) {
    
    Api.sharedInstance.send(xLib6000.Slice.kCmd + value + " 0x\(id)")
  }
  /// Set a Slice property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func sliceCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(xLib6000.Slice.kSetCmd + "0x\(id) " + token.rawValue + "=\(value)")
  }
  /// Set an Audio property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func audioCmd(_ token: String, value: Any) {
    
    Api.sharedInstance.send(xLib6000.Slice.kAudioCmd + "0x\(id) " + token + " \(value)")
  }
  /// Set a Filter property on the Radio
  ///
  /// - Parameters:
  ///   - value:      the new value
  ///
  private func filterCmd(low: Any, high: Any) {
    
    Api.sharedInstance.send(xLib6000.Slice.kFilterCmd + "0x\(id)" + " \(low)" + " \(high)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send Commands to the Radio (hardware)
  
  public func setRecord(_ value: Bool) { Api.sharedInstance.send(xLib6000.Slice.kSetCmd + "\(id) record=\(value.asNumber())") }
  
  public func setPlay(_ value: Bool) { Api.sharedInstance.send(xLib6000.Slice.kSetCmd + "\(id) play=\(value.asNumber())") }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // ***** AUDIO COMMANDS *****
  
  @objc dynamic public var audioGain: Int {
    get { return _audioGain }
    set { if _audioGain != newValue { if newValue.within(Radio.kMin, Radio.kMax) { _audioGain = newValue ; audioCmd("gain", value: newValue) } } } }
  
  @objc dynamic public var audioMute: Bool {
    get { return _audioMute }
    set { if _audioMute != newValue { _audioMute = newValue ; audioCmd("mute", value: newValue.asNumber()) } } }
  
  @objc dynamic public var audioPan: Int {
    get { return _audioPan }
    set { if _audioPan != newValue { if newValue.within(Radio.kMin, Radio.kMax) { _audioGain = newValue ; audioCmd("pan", value: newValue) } } } }
  
  // ***** FILTER COMMANDS *****

  @objc dynamic public var filterHigh: Int {
    get { return _filterHigh }
    set { if _filterHigh != newValue { let value = filterHighLimits(newValue) ; _filterHigh = value ; filterCmd( low: _filterLow, high: value) } } }
  
  @objc dynamic public var filterLow: Int {
    get { return _filterLow }
    set { if _filterLow != newValue { let value = filterLowLimits(newValue) ; _filterLow = value ; filterCmd( low: value, high: _filterHigh) } } }
  
  // ***** SLICE LOCK COMMANDS *****
  
  @objc dynamic public var locked: Bool {
    get { return _locked }
    set { if _locked != newValue { _locked = newValue ; sliceLock( newValue == true ? "lock" : "unlock") } } }
  
  // ***** SLICE COMMANDS *****
  
  // listed in alphabetical order
  @objc dynamic public var active: Bool {
    get { return _active }
    set { if _active != newValue { _active = newValue ; sliceCmd( .active, newValue.asNumber()) } } }
  
  @objc dynamic public var agcMode: String {
    get { return _agcMode }
    set { if _agcMode != newValue { _agcMode = newValue ; sliceCmd( .agcMode, newValue) } } }
  
  @objc dynamic public var agcOffLevel: Int {
    get { return _agcOffLevel }
    set { if _agcOffLevel != newValue { if newValue.within(Radio.kMin, Radio.kMax) {  _agcOffLevel = newValue ; sliceCmd( .agcOffLevel, newValue) } } } }
  
  @objc dynamic public var agcThreshold: Int {
    get { return _agcThreshold }
    set { if _agcThreshold != newValue { if newValue.within(Radio.kMin, Radio.kMax) { _agcThreshold = newValue ; sliceCmd( .agcThreshold, newValue) } } } }
  
  @objc dynamic public var anfEnabled: Bool {
    get { return _anfEnabled }
    set { if _anfEnabled != newValue { _anfEnabled = newValue ; sliceCmd( .anfEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var anfLevel: Int {
    get { return _anfLevel }
    set { if _anfLevel != newValue { if newValue.within(Radio.kMin, Radio.kMax) { _anfLevel = newValue ; sliceCmd( .anfLevel, newValue) } } } }
  
  @objc dynamic public var apfEnabled: Bool {
    get { return _apfEnabled }
    set { if _apfEnabled != newValue { _apfEnabled = newValue ; sliceCmd( .apfEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var apfLevel: Int {
    get { return _apfLevel }
    set { if _apfLevel != newValue { if newValue.within(Radio.kMin, Radio.kMax) { _apfLevel = newValue ; sliceCmd( .apfLevel, newValue) } } } }
  
  @objc dynamic public var daxChannel: Int {
    get { return _daxChannel }
    set { if _daxChannel != newValue { _daxChannel = newValue ; sliceCmd(.daxChannel, newValue) } } }
  
  @objc dynamic public var dfmPreDeEmphasisEnabled: Bool {
    get { return _dfmPreDeEmphasisEnabled }
    set { if _dfmPreDeEmphasisEnabled != newValue { _dfmPreDeEmphasisEnabled = newValue ; sliceCmd(.dfmPreDeEmphasisEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var digitalLowerOffset: Int {
    get { return _digitalLowerOffset }
    set { if _digitalLowerOffset != newValue { _digitalLowerOffset = newValue ; sliceCmd(.digitalLowerOffset, newValue) } } }
  
  @objc dynamic public var digitalUpperOffset: Int {
    get { return _digitalUpperOffset }
    set { if _digitalUpperOffset != newValue { _digitalUpperOffset = newValue ; sliceCmd(.digitalUpperOffset, newValue) } } }
  
  @objc dynamic public var diversityEnabled: Bool {
    get { return _diversityEnabled }
    set { if _diversityEnabled != newValue { _diversityEnabled = newValue ; sliceCmd(.diversityEnabled, newValue.asNumber()) } } } 
  
  @objc dynamic public var fmDeviation: Int {
    get { return _fmDeviation }
    set { if _fmDeviation != newValue { _fmDeviation = newValue ; sliceCmd(.fmDeviation, newValue) } } }
  
  @objc dynamic public var fmRepeaterOffset: Float {
    get { return _fmRepeaterOffset }
    set { if _fmRepeaterOffset != newValue { _fmRepeaterOffset = newValue ; sliceCmd( .fmRepeaterOffset, newValue) } } }
  
  @objc dynamic public var fmToneBurstEnabled: Bool {
    get { return _fmToneBurstEnabled }
    set { if _fmToneBurstEnabled != newValue { _fmToneBurstEnabled = newValue ; sliceCmd( .fmToneBurstEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var fmToneFreq: Float {
    get { return _fmToneFreq }
    set { if _fmToneFreq != newValue { _fmToneFreq = newValue ; sliceCmd( .fmToneFreq, newValue) } } }
  
  @objc dynamic public var fmToneMode: String {
    get { return _fmToneMode }
    set { if _fmToneMode != newValue { _fmToneMode = newValue ; sliceCmd( .fmToneMode, newValue) } } }
  
  @objc dynamic public var loopAEnabled: Bool {
    get { return _loopAEnabled }
    set { if _loopAEnabled != newValue { _loopAEnabled = newValue ; sliceCmd( .loopAEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var loopBEnabled: Bool {
    get { return _loopBEnabled }
    set { if _loopBEnabled != newValue { _loopBEnabled = newValue ; sliceCmd( .loopBEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var mode: String {
    get { return _mode }
    set { if _mode != newValue { _mode = newValue ; sliceCmd( .mode, newValue) } } }
  
  @objc dynamic public var nbEnabled: Bool {
    get { return _nbEnabled }
    set { if _nbEnabled != newValue { _nbEnabled = newValue ; sliceCmd( .nbEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var nbLevel: Int {
    get { return _nbLevel }
    set { if _nbLevel != newValue { if newValue.within(Radio.kMin, Radio.kMax) {  _nbLevel = newValue ; sliceCmd( .nbLevel, newValue) } } } }
  
  @objc dynamic public var nrEnabled: Bool {
    get { return _nrEnabled }
    set { if _nrEnabled != newValue { _nrEnabled = newValue ; sliceCmd( .nrEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var nrLevel: Int {
    get { return _nrLevel }
    set { if _nrLevel != newValue { if newValue.within(Radio.kMin, Radio.kMax) {  _nrLevel = newValue ; sliceCmd( .nrLevel, newValue) } } } }
  
  @objc dynamic public var playbackEnabled: Bool {
    get { return _playbackEnabled }
    set { if _playbackEnabled != newValue { _playbackEnabled = newValue ; sliceCmd( .playbackEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var recordEnabled: Bool {
    get { return _recordEnabled }
    set { if recordEnabled != newValue { _recordEnabled = newValue ; sliceCmd( .recordEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var repeaterOffsetDirection: String {
    get { return _repeaterOffsetDirection }
    set { if _repeaterOffsetDirection != newValue { _repeaterOffsetDirection = newValue ; sliceCmd( .repeaterOffsetDirection, newValue) } } }
  
  @objc dynamic public var rfGain: Int {
    get { return _rfGain }
    set { if _rfGain != newValue { _rfGain = newValue ; sliceCmd( .rfGain, newValue) } } }
  
  @objc dynamic public var ritEnabled: Bool {
    get { return _ritEnabled }
    set { if _ritEnabled != newValue { _ritEnabled = newValue ; sliceCmd( .ritEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var ritOffset: Int {
    get { return _ritOffset }
    set { if _ritOffset != newValue { if newValue.within(Slice.kMinOffset, Slice.kMaxOffset) {  _ritOffset = newValue ; sliceCmd( .ritOffset, newValue) } } } }
  
  @objc dynamic public var rttyMark: Int {
    get { return _rttyMark }
    set { if _rttyMark != newValue { _rttyMark = newValue ; sliceCmd( .rttyMark, newValue) } } }
  
  @objc dynamic public var rttyShift: Int {
    get { return _rttyShift }
    set { if _rttyShift != newValue { _rttyShift = newValue ; sliceCmd( .rttyShift, newValue) } } }
  
  @objc dynamic public var rxAnt: Radio.AntennaPort {
    get { return _rxAnt }
    set { if _rxAnt != newValue { _rxAnt = newValue ; sliceCmd( .rxAnt, newValue) } } }
  
  @objc dynamic public var step: Int {
    get { return _step }
    set { if _step != newValue { _step = newValue ; sliceCmd( .step, newValue) } } }
  
  @objc dynamic public var stepList: String {
    get { return _stepList }
    set { if _stepList != newValue { _stepList = newValue ; sliceCmd( .stepList, newValue) } } }
  
  @objc dynamic public var squelchEnabled: Bool {
    get { return _squelchEnabled }
    set { if _squelchEnabled != newValue { _squelchEnabled = newValue ; sliceCmd( .squelchEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var squelchLevel: Int {
    get { return _squelchLevel }
    set { if _squelchLevel != newValue { if newValue.within(Radio.kMin, Radio.kMax) {  _squelchLevel = newValue ; sliceCmd( .squelchLevel, newValue) } } } }
  
  @objc dynamic public var txAnt: String {
    get { return _txAnt }
    set { if _txAnt != newValue { _txAnt = newValue ; sliceCmd( .txAnt, newValue) } } }
  
  @objc dynamic public var txEnabled: Bool {
    get { return _txEnabled }
    set { if _txEnabled != newValue { _txEnabled = newValue ; sliceCmd( .txEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var txOffsetFreq: Float {
    get { return _txOffsetFreq }
    set { if _txOffsetFreq != newValue { _txOffsetFreq = newValue ;sliceCmd( .txOffsetFreq, newValue) } } }
  
  @objc dynamic public var wnbEnabled: Bool {
    get { return _wnbEnabled }
    set { if _wnbEnabled != newValue { _wnbEnabled = newValue ; sliceCmd( .wnbEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var wnbLevel: Int {
    get { return _wnbLevel }
    set { if wnbLevel != newValue { if newValue.within(Radio.kMin, Radio.kMax) {  _wnbLevel = newValue ; sliceCmd( .wnbLevel, newValue) } } } }
  
  @objc dynamic public var xitEnabled: Bool {
    get { return _xitEnabled }
    set { if _xitEnabled != newValue { _xitEnabled = newValue ; sliceCmd( .xitEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var xitOffset: Int {
    get { return _xitOffset }
    set { if _xitOffset != newValue { if newValue.within(Slice.kMinOffset, Slice.kMaxOffset) {  _xitOffset = newValue ; sliceCmd( .xitOffset, newValue) } } } }
  
  // ***** TUNE COMMANDS *****
  
  @objc dynamic public var frequency: Int {
    get { return _frequency }
    set { if !_locked { if _frequency != newValue { _frequency = newValue ; sliceTuneCmd( newValue.hzToMhz()) } } } }
}
