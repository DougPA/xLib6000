//
//  Equalizer.swift
//  xLib6000
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

public typealias EqualizerId = String

/// Equalizer Class implementation
///
///      creates an Equalizer instance to be used by a Client to support the
///      rendering of an Equalizer. Equalizer objects are added, removed and
///      updated by the incoming TCP messages. They are collected in the equalizers
///      collection on the Radio object.
///
///      Note: ignores the non-"sc" version of Equalizer messages
///            The "sc" version is the standard for API Version 1.4 and greater
///
public final class Equalizer                : NSObject, DynamicModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kCmd                           = "eq "                         // Command prefixes

  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : EqualizerId                   // Rx/Tx Equalizer

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

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
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods
  
  /// Parse a Stream status message
  ///
  ///   StatusParser Protocol method, executes on the parseQ
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
//      let log = OSLog(subsystem:Api.kBundleIdentifier, category: "Equalizer")
//      os_log("Unknown EQ - %{public}@", log: log, type: .default, type)
      Api.sharedInstance.log.msg( "Unknown EQ - \(type)", level: .info, function: #function, file: #file, line: #line)

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
  ///   - queue:              Concurrent queue
  ///
  init(id: EqualizerId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }

  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods

  /// Parse Equalizer key/value pairs
  ///
  ///   PropertiesParser Protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        
        // unknown Key, log it and ignore the Key
        _api.log.msg( "Unknown Equalizer token - \(property.key) = \(property.value)", level: .info, function: #function, file: #file, line: #line)

        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
      case .level63Hz:
        willChangeValue(for: \.level63Hz)
        _level63Hz = property.value.iValue
        didChangeValue(for: \.level63Hz)

      case .level125Hz:
        willChangeValue(for: \.level125Hz)
        _level125Hz = property.value.iValue
        didChangeValue(for: \.level125Hz)

      case .level250Hz:
        willChangeValue(for: \.level250Hz)
        _level250Hz = property.value.iValue
        didChangeValue(for: \.level250Hz)

      case .level500Hz:
        willChangeValue(for: \.level500Hz)
        _level500Hz = property.value.iValue
        didChangeValue(for: \.level500Hz)

      case .level1000Hz:
        willChangeValue(for: \.level1000Hz)
        _level1000Hz = property.value.iValue
        didChangeValue(for: \.level1000Hz)

      case .level2000Hz:
        willChangeValue(for: \.level2000Hz)
        _level2000Hz = property.value.iValue
        didChangeValue(for: \.level2000Hz)

      case .level4000Hz:
        willChangeValue(for: \.level4000Hz)
        _level4000Hz = property.value.iValue
        didChangeValue(for: \.level4000Hz)

      case .level8000Hz:
        willChangeValue(for: \.level8000Hz)
        _level8000Hz = property.value.iValue
        didChangeValue(for: \.level8000Hz)

      case .enabled:
        willChangeValue(for: \.eqEnabled)
        _eqEnabled = property.value.bValue
        didChangeValue(for: \.eqEnabled)
      }
    }
    // is the Equalizer initialized?
    if !_initialized {
      // NO, the Radio (hardware) has acknowledged this Equalizer
      _initialized = true
      
      // notify all observers
      NC.post(.equalizerHasBeenAdded, object: self as Any?)
    }
  }
}

extension Equalizer {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
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
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum Token : String {
    case level63Hz                          = "63hz"            // "63Hz"
    case level125Hz                         = "125hz"           // "125Hz"
    case level250Hz                         = "250hz"           // "250Hz"
    case level500Hz                         = "500hz"           // "500Hz"
    case level1000Hz                        = "1000hz"          // "1000Hz"
    case level2000Hz                        = "2000hz"          // "2000Hz"
    case level4000Hz                        = "4000hz"          // "4000Hz"
    case level8000Hz                        = "8000hz"          // "8000Hz"
    case enabled                            = "mode"
  }
  /// Types
  ///
  public enum EqType: String {
    case rx                                 // deprecated type
    case rxsc
    case tx                                 // deprecated type
    case txsc
  }
  
}
