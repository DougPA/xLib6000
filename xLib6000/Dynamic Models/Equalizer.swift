//
//  Equalizer.swift
//  xLib6000
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

public typealias EqualizerId = String

// ------------------------------------------------------------------------------
// MARK: - Equalizer Class implementation
//
//      creates an Equalizer instance to be used by a Client to support the
//      rendering of an Equalizer. Equalizer objects are added, removed and
//      updated by the incoming TCP messages.
//
//      Note: ignores the non-"sc" version of Equalizer messages
//            The "sc" version is the standard for API Version 1.4 and greater
//
// ------------------------------------------------------------------------------

public final class Equalizer                : NSObject, StatusParser, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : EqualizerId                   // Rx/Tx Equalizer

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __eqEnabled                   = false                         // enabled flag
  private var __level63Hz                   = 0                             // level settings
  private var __level125Hz                  = 0
  private var __level250Hz                  = 0
  private var __level500Hz                  = 0
  private var __level1000Hz                 = 0
  private var __level2000Hz                 = 0
  private var __level4000Hz                 = 0
  private var __level8000Hz                 = 0
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ----------------------------------------------------------------------------
  // MARK: - StatusParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse a Stream status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format: <type, ""> <"mode", 1|0>, <"63Hz", value> <"125Hz", value> <"250Hz", value> <"500Hz", value>
    //          <"1000Hz", value> <"2000Hz", value> <"4000Hz", value> <"8000Hz", value>
    
    var equalizer: Equalizer?
    
    // get the Type
    let type = keyValues[0].key
    
    // determine the type of Equalizer
    switch type {
      
    case EqType.txsc.rawValue:
      // transmit equalizer
      equalizer = radio.equalizers[.txsc]
      
    case EqType.rxsc.rawValue:
      // receive equalizer
      equalizer = radio.equalizers[.rxsc]
      
    case EqType.rx.rawValue, EqType.tx.rawValue:
      // obslete type, ignore it
      break
      
    default:
      // unknown type, log & ignore it
      Log.sharedInstance.msg("Unknown EQ - \(type)", level: .debug, function: #function, file: #file, line: #line)
    }
    // if an equalizer was found
    if let equalizer = equalizer {
      
      // pass the key values to the Equalizer for parsing (dropping the Type)
      equalizer.parseProperties( Array(keyValues.dropFirst(1)) )
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an Equalizer
  ///
  /// - Parameters:
  ///   - eqType:             the Equalizer type (rxsc or txsc)
  ///   - radio:              the parent Radio class
  ///   - queue:              Concurrent queue
  ///
  init(id: EqualizerId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }

  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse Equalizer key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        
        // unknown Key, log it and ignore the Key
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
      case .level63Hz:
        willChangeValue(forKey: "level63Hz")
        _level63Hz = property.value.iValue()
        didChangeValue(forKey: "level63Hz")
        
      case .level125Hz:
        willChangeValue(forKey: "level125Hz")
        _level125Hz = property.value.iValue()
        didChangeValue(forKey: "level125Hz")
        
      case .level250Hz:
        willChangeValue(forKey: "level250Hz")
        _level250Hz = property.value.iValue()
        didChangeValue(forKey: "level250Hz")
        
      case .level500Hz:
        willChangeValue(forKey:  "level500Hz")
        _level500Hz = property.value.iValue()
        didChangeValue(forKey:  "level500Hz")
        
      case .level1000Hz:
        willChangeValue(forKey: "level1000Hz")
        _level1000Hz = property.value.iValue()
        didChangeValue(forKey: "level1000Hz")
        
      case .level2000Hz:
        willChangeValue(forKey: "level2000Hz")
        _level2000Hz = property.value.iValue()
        didChangeValue(forKey: "level2000Hz")
        
      case .level4000Hz:
        willChangeValue(forKey: "level4000Hz")
        _level4000Hz = property.value.iValue()
        didChangeValue(forKey: "level4000Hz")
        
      case .level8000Hz:
        willChangeValue(forKey: "level8000Hz")
        _level8000Hz = property.value.iValue()
        didChangeValue(forKey: "level8000Hz")
        
      case .enabled:
        willChangeValue(forKey: "eqEnabled")
        _eqEnabled = property.value.bValue()
        didChangeValue(forKey: "eqEnabled")
      }
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Equalizer Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Equalizer tokens
// --------------------------------------------------------------------------------

extension Equalizer {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  internal var _eqEnabled: Bool {
    get { return _q.sync { __eqEnabled } }
    set { _q.sync(flags: .barrier) { __eqEnabled = newValue } } }
  
  internal var _level63Hz: Int {
    get { return _q.sync { __level63Hz } }
    set { _q.sync(flags: .barrier) { __level63Hz = newValue } } }
  
  internal var _level125Hz: Int {
    get { return _q.sync { __level125Hz } }
    set { _q.sync(flags: .barrier) { __level125Hz = newValue } } }
  
  internal var _level250Hz: Int {
    get { return _q.sync { __level250Hz } }
    set { _q.sync(flags: .barrier) { __level250Hz = newValue } } }
  
  internal var _level500Hz: Int {
    get { return _q.sync { __level500Hz } }
    set { _q.sync(flags: .barrier) { __level500Hz = newValue } } }
  
  internal var _level1000Hz: Int {
    get { return _q.sync { __level1000Hz } }
    set { _q.sync(flags: .barrier) { __level1000Hz = newValue } } }
  
  internal var _level2000Hz: Int {
    get { return _q.sync { __level2000Hz } }
    set { _q.sync(flags: .barrier) { __level2000Hz = newValue } } }
  
  internal var _level4000Hz: Int {
    get { return _q.sync { __level4000Hz } }
    set { _q.sync(flags: .barrier) { __level4000Hz = newValue } } }
  
  internal var _level8000Hz: Int {
    get { return _q.sync { __level8000Hz } }
    set { _q.sync(flags: .barrier) { __level8000Hz = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // ----- None -----
  
  // ----------------------------------------------------------------------------
  // Mark: - Equalizer tokens
  
  internal enum Token : String {
    case level63Hz                          = "63hz"
    case level125Hz                         = "125hz"
    case level250Hz                         = "250hz"
    case level500Hz                         = "500hz"
    case level1000Hz                        = "1000hz"
    case level2000Hz                        = "2000hz"
    case level4000Hz                        = "4000hz"
    case level8000Hz                        = "8000hz"
    case enabled                            = "mode"
  }
  public enum EqType: String {
    case rx                                 // deprecated type
    case rxsc
    case tx                                 // deprecated type
    case txsc
  }
  
}
