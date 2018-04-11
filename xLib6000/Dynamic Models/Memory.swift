//
//  Memory.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/20/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

public typealias MemoryId = String

// --------------------------------------------------------------------------------
// MARK: - Memory Class implementation
//
//      creates a Memory instance to be used by a Client to support the
//      processing of a Memory. Memory objects are added, removed and
//      updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Memory                   : NSObject, StatusParser, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : MemoryId                      // Id that uniquely identifies this Memory

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __digitalLowerOffset          = 0                             // Digital Lower Offset
  private var __digitalUpperOffset          = 0                             // Digital Upper Offset
  private var __filterHigh                  = 0                             // Filter high
  private var __filterLow                   = 0                             // Filter low
  private var __frequency                   = 0                             // Frequency (Hz)
  private var __group                       = ""                            // Group
  private var __mode                        = ""                            // Mode
  private var __name                        = ""                            // Name
  private var __offset                      = 0                             // Offset (Hz)
  private var __offsetDirection             = ""                            // Offset direction
  private var __owner                       = ""                            // Owner
  private var __rfPower                     = 0                             // Rf Power
  private var __rttyMark                    = 0                             // RTTY Mark
  private var __rttyShift                   = 0                             // RTTY Shift
  private var __squelchEnabled              = false                         // Squelch enabled
  private var __squelchLevel                = 0                             // Squelch level
  private var __step                        = 0                             // Step (Hz)
  private var __toneMode                    = ""                            // Tone Mode
  private var __toneValue                   = 0                             // Tone values (Hz)
  //                                                                                                  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ----------------------------------------------------------------------------
  // MARK: - StatusParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a Memory status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    var memory: Memory?
    
    // get the Memory Id
    let memoryId = keyValues[0].key
    
    // is the Memory in use?
    if inUse {
      
      // YES, does it exist?
      memory = radio.memories[memoryId]
      if memory == nil {
        
        // NO, create a new Memory & add it to the Memories collection
        memory = Memory(id: memoryId, queue: queue)
        radio.memories[memoryId] = memory
      }
      // pass the key values to the Memory for parsing (dropping the Id)
      memory!.parseProperties( Array(keyValues.dropFirst(1)) )
      
    } else {
      
      // NO, notify all observers
      NC.post(.memoryWillBeRemoved, object: radio.memories[memoryId] as Any?)
      
      // remove it
      radio.memories[memoryId] = nil
    }
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Memory
  ///
  /// - Parameters:
  ///   - id:                 a Memory Id
  ///   - radio:              the parent Radio class
  ///   - queue:              Concurrent queue
  ///
  init(id: MemoryId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public methods that send commands to the Radio (hardware)
  
  public func select() { Api.sharedInstance.send("memory apply \(id)") }
  
  // ------------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Restrict the Filter High value
  ///
  /// - Parameters:
  ///   - value:          the value
  /// - Returns:          adjusted value
  ///
  func filterHighLimits(_ value: Int) -> Int {
    
    var newValue = (value < filterHigh + 10 ? filterHigh + 10 : value)
    
    if let modeType = Slice.Mode(rawValue: mode.lowercased()) {
      switch modeType {
        
      case .cw:
        newValue = (newValue > 12_000 - Api.sharedInstance.radio!.transmit.cwPitch ? 12_000 - Api.sharedInstance.radio!.transmit.cwPitch : newValue)
        
      case .rtty:
        newValue = (newValue > 4_000 ? 4_000 : newValue)
        
      case .dsb, .am, .sam, .fm, .nfm, .dfm, .dstr:
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
    
    if let modeType = Slice.Mode(rawValue: mode.lowercased()) {
      switch modeType {
        
      case .cw:
        newValue = (newValue < -12_000 - Api.sharedInstance.radio!.transmit.cwPitch ? -12_000 - Api.sharedInstance.radio!.transmit.cwPitch : newValue)
        
      case .rtty:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
        
      case .dsb, .am, .sam, .fm, .nfm, .dfm, .dstr:
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
  /// Validate the Tone Value
  ///
  /// - Parameters:
  ///   - value:          a Tone Value
  /// - Returns:          true = Valid
  ///
  func toneValueValid( _ value: Int) -> Bool {
    
    return toneMode == ToneMode.ctcssTx.rawValue && toneValue.within(0, 301)
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse Memory key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray)  {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = Token(rawValue: property.key) else {
        // unknown token, log it and ignore the token
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch (token) {
        
      case .digitalLowerOffset:
        willChangeValue(forKey: "digitalLowerOffset")
        _digitalLowerOffset = property.value.iValue()
        didChangeValue(forKey: "digitalLowerOffset")
        
      case .digitalUpperOffset:
        willChangeValue(forKey: "digitalUpperOffset")
        _digitalUpperOffset = property.value.iValue()
        didChangeValue(forKey: "digitalUpperOffset")
        
      case .frequency:
        willChangeValue(forKey: "frequency")
        _frequency = property.value.mhzToHz()
        didChangeValue(forKey: "frequency")
        
      case .group:
        willChangeValue(forKey: "group")
        _group = property.value.replacingSpaces()
        didChangeValue(forKey: "group")
        
      case .highlight:            // not implemented
        break
        
      case .highlightColor:       // not implemented
        break
        
      case .mode:
        willChangeValue(forKey: "mode")
        _mode = property.value.replacingSpaces()
        didChangeValue(forKey: "mode")
        
      case .name:
        willChangeValue(forKey: "name")
        _name = property.value.replacingSpaces()
        didChangeValue(forKey: "name")
        
      case .owner:
        willChangeValue(forKey: "owner")
        _owner = property.value.replacingSpaces()
        didChangeValue(forKey: "owner")
        
      case .repeaterOffsetDirection:
        willChangeValue(forKey: "offsetDirection")
        _offsetDirection = property.value.replacingSpaces()
        didChangeValue(forKey: "offsetDirection")
        
      case .repeaterOffset:
        willChangeValue(forKey: "offset")
        _offset = property.value.iValue()
        didChangeValue(forKey: "offset")
        
      case .rfPower:
        willChangeValue(forKey: "rfPower")
        _rfPower = property.value.iValue()
        didChangeValue(forKey: "rfPower")
        
      case .rttyMark:
        willChangeValue(forKey: "rttyMark")
        _rttyMark = property.value.iValue()
        didChangeValue(forKey: "rttyMark")
        
      case .rttyShift:
        willChangeValue(forKey: "rttyShift")
        _rttyShift = property.value.iValue()
        didChangeValue(forKey: "rttyShift")
        
      case .rxFilterHigh:
        willChangeValue(forKey: "filterHigh")
        _filterHigh = filterHighLimits(property.value.iValue())
        didChangeValue(forKey: "filterHigh")
        
      case .rxFilterLow:
        willChangeValue(forKey: "filterLow")
        _filterLow = filterLowLimits(property.value.iValue())
        didChangeValue(forKey: "filterLow")
        
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
        
      case .toneMode:
        willChangeValue(forKey: "toneMode")
        _toneMode = property.value.replacingSpaces()
        didChangeValue(forKey: "toneMode")
        
      case .toneValue:
        willChangeValue(forKey: "toneValue")
        _toneValue = property.value.iValue()
        didChangeValue(forKey: "toneValue")
      }
    }
    // is the Memory initialized?
    if !_initialized  {
      
      // YES, the Radio (hardware) has acknowledged this Memory
      _initialized = true
      
      // notify all observers
      NC.post(.memoryHasBeenAdded, object: self as Any?)
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Memory Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Memory tokens
// --------------------------------------------------------------------------------

extension Memory {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _digitalLowerOffset: Int {
    get { return _q.sync { __digitalLowerOffset } }
    set { _q.sync(flags: .barrier) { __digitalLowerOffset = newValue } } }
  
  internal var _digitalUpperOffset: Int {
    get { return _q.sync { __digitalUpperOffset } }
    set { _q.sync(flags: .barrier) { __digitalUpperOffset = newValue } } }
  
  internal var _filterHigh: Int {
    get { return _q.sync { __filterHigh } }
    set { _q.sync(flags: .barrier) { __filterHigh = newValue } } }
  
  internal var _filterLow: Int {
    get { return _q.sync { __filterLow } }
    set { _q.sync(flags: .barrier) { __filterLow = newValue } } }
  
  internal var _frequency: Int {
    get { return _q.sync { __frequency } }
    set { _q.sync(flags: .barrier) { __frequency = newValue } } }
  
  internal var _group: String {
    get { return _q.sync { __group } }
    set { _q.sync(flags: .barrier) { __group = newValue } } }
  
  internal var _mode: String {
    get { return _q.sync { __mode } }
    set { _q.sync(flags: .barrier) { __mode = newValue } } }
  
  internal var _name: String {
    get { return _q.sync { __name } }
    set { _q.sync(flags: .barrier) { __name = newValue } } }
  
  internal var _offset: Int {
    get { return _q.sync { __offset } }
    set { _q.sync(flags: .barrier) { __offset = newValue } } }
  
  internal var _offsetDirection: String {
    get { return _q.sync { __offsetDirection } }
    set { _q.sync(flags: .barrier) { __offsetDirection = newValue } } }
  
  internal var _owner: String {
    get { return _q.sync { __owner } }
    set { _q.sync(flags: .barrier) { __owner = newValue } } }
  
  internal var _rfPower: Int {
    get { return _q.sync { __rfPower } }
    set { _q.sync(flags: .barrier) { __rfPower = newValue } } }
  
  internal var _rttyMark: Int {
    get { return _q.sync { __rttyMark } }
    set { _q.sync(flags: .barrier) { __rttyMark = newValue } } }
  
  internal var _rttyShift: Int {
    get { return _q.sync { __rttyShift } }
    set { _q.sync(flags: .barrier) { __rttyShift = newValue } } }
  
  internal var _squelchEnabled: Bool {
    get { return _q.sync { __squelchEnabled } }
    set { _q.sync(flags: .barrier) { __squelchEnabled = newValue } } }
  
  internal var _squelchLevel: Int {
    get { return _q.sync { __squelchLevel } }
    set { _q.sync(flags: .barrier) { __squelchLevel = newValue } } }
  
  internal var _step: Int {
    get { return _q.sync { __step } }
    set { _q.sync(flags: .barrier) { __step = newValue } } }
  
  internal var _toneMode: String {
    get { return _q.sync { __toneMode } }
    set { _q.sync(flags: .barrier) { __toneMode = newValue } } }
  
  internal var _toneValue: Int {
    get { return _q.sync { __toneValue } }
    set { _q.sync(flags: .barrier) { __toneValue = newValue } } }
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // ----- None -----
  
  // ----------------------------------------------------------------------------
  // Mark: - Memory tokens
  
  internal enum Token : String {
    case digitalLowerOffset                 = "digl_offset"
    case digitalUpperOffset                 = "digu_offset"
    case frequency                          = "freq"
    case group
    case highlight
    case highlightColor                     = "highlight_color"
    case mode
    case name
    case owner
    case repeaterOffsetDirection            = "repeater"
    case repeaterOffset                     = "repeater_offset"
    case rfPower                            = "power"
    case rttyMark                           = "rtty_mark"
    case rttyShift                          = "rtty_shift"
    case rxFilterHigh                       = "rx_filter_high"
    case rxFilterLow                        = "rx_filter_low"
    case step
    case squelchEnabled                     = "squelch"
    case squelchLevel                       = "squelch_level"
    case toneMode                           = "tone_mode"
    case toneValue                          = "tone_value"
  }
  
  // ----------------------------------------------------------------------------
  // Mark: - Memory related enums
  
  public enum TXOffsetDirection : String {  // Tx offset types
    case down
    case simplex
    case up
  }
  
  public enum ToneMode : String {           // Tone modes
    case ctcssTx = "ctcss_tx"
    case off
  }
  
}
