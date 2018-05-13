//
//  Xvtr.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/24/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

public typealias XvtrId = String

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Xvtr Class implementation
//
//      creates an Xvtr instance to be used by a Client to support the
//      processing of an Xvtr. Xvtr objects are added, removed and updated by
//      the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Xvtr                     : NSObject, StatusParser, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : XvtrId = ""                   // Id that uniquely identifies this Xvtr

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _api                          = Api.sharedInstance            // reference to the API singleton
  private var _q                            : DispatchQueue                 // Q for object synchronization
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
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse an Xvtr status message
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
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse Xvtr key/value pairs
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
        
      case .name:
        _api.update(self, property: &_name, value: property.value, key: "name")

      case .ifFrequency:
        _api.update(self, property: &_ifFrequency, value: property.value.iValue(), key: "ifFrequency")

      case .inUse:
        _api.update(self, property: &_inUse, value: property.value.bValue(), key: "inUse")

      case .isValid:
        _api.update(self, property: &_isValid, value: property.value.bValue(), key: "isValid")

      case .loError:
        _api.update(self, property: &_loError, value: property.value.iValue(), key: "loError")

      case .maxPower:
        _api.update(self, property: &_maxPower, value: property.value.iValue(), key: "maxPower")

      case .order:
        _api.update(self, property: &_order, value: property.value.iValue(), key: "order")

      case .preferred:
        _api.update(self, property: &_preferred, value: property.value.bValue(), key: "preferred")

      case .rfFrequency:
        _api.update(self, property: &_rfFrequency, value: property.value.iValue(), key: "rfFrequency")

      case .rxGain:
        _api.update(self, property: &_rxGain, value: property.value.iValue(), key: "rxGain")

      case .rxOnly:
        _api.update(self, property: &_rxOnly, value: property.value.bValue(), key: "rxOnly")

      case .twoMeterInt:
        _api.update(self, property: &_twoMeterInt, value: property.value.iValue(), key: "twoMeterInt")
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

// --------------------------------------------------------------------------------
// MARK: - Xvtr Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Xvtr tokens
// --------------------------------------------------------------------------------

extension Xvtr {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
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
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var inUse: Bool {
    return _inUse }
  
  @objc dynamic public var isValid: Bool {
    return _isValid }
  
  @objc dynamic public var preferred: Bool {
    return _preferred }
  
  @objc dynamic public var twoMeterInt: Int {
    return _twoMeterInt }
  
  // ----------------------------------------------------------------------------
  // MARK: - Xvtr tokens
  
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
