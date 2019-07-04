//
//  Xvtr.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/24/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

public typealias XvtrId = String

import Foundation

/// Xvtr Class implementation
///
///      creates an Xvtr instance to be used by a Client to support the
///      processing of an Xvtr. Xvtr objects are added, removed and updated by
///      the incoming TCP messages. They are collected in the xvtrs
///      collection on the Radio object.
///
public final class Xvtr                     : NSObject, DynamicModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : XvtrId = ""                   // Id that uniquely identifies this Xvtr

  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //                                                                                              
  private var __name                        = ""                            // Xvtr Name
  private var __ifFrequency                 = 0                             // If Frequency
  private var __inUse                       = false                         //
  private var __isValid                     = false                         //
  private var __loError                     = 0                             //
  private var __maxPower                    = 0                             //
  private var __order                       = 0                             //
  private var __preferred                   = false                         //
  private var __rfFrequency                 = 0                             //
  private var __rxGain                      = 0                             //
  private var __rxOnly                      = false                         //
  private var __twoMeterInt                 = 0                             //
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods
  
  /// Parse an Xvtr status message
  ///
  ///   StatusParser protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <name, > <"rf_freq", value> <"if_freq", value> <"lo_error", value> <"max_power", value>
    //              <"rx_gain",value> <"order", value> <"rx_only", 1|0> <"is_valid", 1|0> <"preferred", 1|0>
    //              <"two_meter_int", value>
    //      OR
    // Format: <index, > <"in_use", 0>
    
    // get the Name
    let name = keyValues[0].key
    
    // isthe Xvtr in use?
    if inUse {
      
      // YES, does the Xvtr exist?
      if radio.xvtrs[name] == nil {
        
        // NO, create a new Xvtr & add it to the Xvtrs collection
        radio.xvtrs[name] = Xvtr(id: name, queue: queue)
      }
      // pass the remaining key values to the Xvtr for parsing (dropping the Id)
      radio.xvtrs[name]!.parseProperties( Array(keyValues.dropFirst(1)) )
      
    } else {
      
      // NO, notify all observers
      NC.post(.xvtrWillBeRemoved, object: radio.xvtrs[name] as Any?)
      
      // remove it
      radio.xvtrs[name] = nil
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an Xvtr
  ///
  /// - Parameters:
  ///   - id:                 an Xvtr Id
  ///   - queue:              Concurrent queue
  ///
  public init(id: XvtrId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods

  /// Parse Xvtr key/value pairs
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        // log it and ignore the Key
        _log.msg("Unknown Xvtr token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .name:
        willChangeValue(for: \.name)
        _name = property.value
        didChangeValue(for: \.name)

      case .ifFrequency:
        willChangeValue(for: \.ifFrequency)
        _ifFrequency = property.value.iValue
        didChangeValue(for: \.ifFrequency)

      case .inUse:
        willChangeValue(for: \.inUse)
        _inUse = property.value.bValue
        didChangeValue(for: \.inUse)

      case .isValid:
        willChangeValue(for: \.isValid)
        _isValid = property.value.bValue
        didChangeValue(for: \.isValid)

      case .loError:
        willChangeValue(for: \.loError)
        _loError = property.value.iValue
        didChangeValue(for: \.loError)

      case .maxPower:
        willChangeValue(for: \.maxPower)
        _maxPower = property.value.iValue
        didChangeValue(for: \.maxPower)

      case .order:
        willChangeValue(for: \.order)
        _order = property.value.iValue
        didChangeValue(for: \.order)

      case .preferred:
        willChangeValue(for: \.preferred)
        _preferred = property.value.bValue
        didChangeValue(for: \.preferred)

      case .rfFrequency:
        willChangeValue(for: \.rfFrequency)
        _rfFrequency = property.value.iValue
        didChangeValue(for: \.rfFrequency)

      case .rxGain:
        willChangeValue(for: \.rxGain)
        _rxGain = property.value.iValue
        didChangeValue(for: \.rxGain)

      case .rxOnly:
        willChangeValue(for: \.rxOnly)
        _rxOnly = property.value.bValue
        didChangeValue(for: \.rxOnly)

      case .twoMeterInt:
        willChangeValue(for: \.twoMeterInt)
        _twoMeterInt = property.value.iValue
        didChangeValue(for: \.twoMeterInt)
      }
    }
    // is the waterfall initialized?
    if !_initialized && _inUse {
      
      // YES, the Radio (hardware) has acknowledged this Waterfall
      _initialized = true
      
      // notify all observers
      NC.post(.xvtrHasBeenAdded, object: self as Any?)
    }
  }
}

extension Xvtr {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _ifFrequency: Int {
    get { return _q.sync { __ifFrequency } }
    set { _q.sync(flags: .barrier) {__ifFrequency = newValue } } }
  
  internal var _inUse: Bool {
    get { return _q.sync { __inUse } }
    set { _q.sync(flags: .barrier) {__inUse = newValue } } }
  
  internal var _isValid: Bool {
    get { return _q.sync { __isValid } }
    set { _q.sync(flags: .barrier) {__isValid = newValue } } }
  
  internal var _loError: Int {
    get { return _q.sync { __loError } }
    set { _q.sync(flags: .barrier) {__loError = newValue } } }
  
  internal var _name: String {
    get { return _q.sync { __name } }
    set { _q.sync(flags: .barrier) {__name = newValue } } }
  
  internal var _maxPower: Int {
    get { return _q.sync { __maxPower } }
    set { _q.sync(flags: .barrier) {__maxPower = newValue } } }
  
  internal var _order: Int {
    get { return _q.sync { __order } }
    set { _q.sync(flags: .barrier) {__order = newValue } } }
  
  internal var _preferred: Bool {
    get { return _q.sync { __preferred } }
    set { _q.sync(flags: .barrier) {__preferred = newValue } } }
  
  internal var _rfFrequency: Int {
    get { return _q.sync { __rfFrequency } }
    set { _q.sync(flags: .barrier) {__rfFrequency = newValue } } }
  
  internal var _rxGain: Int {
    get { return _q.sync { __rxGain } }
    set { _q.sync(flags: .barrier) {__rxGain = newValue } } }
  
  internal var _rxOnly: Bool {
    get { return _q.sync { __rxOnly } }
    set { _q.sync(flags: .barrier) {__rxOnly = newValue } } }
  
  internal var _twoMeterInt: Int {
    get { return _q.sync { __twoMeterInt } }
    set { _q.sync(flags: .barrier) {__twoMeterInt = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var inUse: Bool {
    return _inUse }
  
  @objc dynamic public var isValid: Bool {
    return _isValid }
  
  @objc dynamic public var preferred: Bool {
    return _preferred }
  
  @objc dynamic public var twoMeterInt: Int {
    return _twoMeterInt }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum Token : String {
    case name
    case ifFrequency        = "if_freq"
    case inUse              = "in_use"
    case isValid            = "is_valid"
    case loError            = "lo_error"
    case maxPower           = "max_power"
    case order
    case preferred
    case rfFrequency        = "rf_freq"
    case rxGain             = "rx_gain"
    case rxOnly             = "rx_only"
    case twoMeterInt        = "two_meter_int"
  }
}
