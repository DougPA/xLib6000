//
//  Interlock.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Interlock Class implementation
//
//      creates an Interlock instance to be used by a Client to support the
//      processing of interlocks. Interlock objects are added, removed and 
//      updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Interlock                : NSObject, StaticModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __accTxEnabled                = false                         //
  private var __accTxDelay                  = 0                             //
  private var __accTxReqEnabled             = false                         //
  private var __accTxReqPolarity            = false                         //
  private var __amplifier                   = ""                            //
  private var __rcaTxReqEnabled             = false                         //
  private var __rcaTxReqPolarity            = false                         //
  private var __reason                      = ""                            //
  private var __source                      = ""                            //
  private var __state                       = ""                            //
  private var __timeout                     = 0                             //
  private var __txAllowed                   = false                         //
  private var __txDelay                     = 0                             //
  private var __tx1Delay                    = 0                             //
  private var __tx1Enabled                  = false                         //
  private var __tx2Delay                    = 0                             //
  private var __tx2Enabled                  = false                         //
  private var __tx3Delay                    = 0                             //
  private var __tx3Enabled                  = false                         //
  //                                                                                              
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Interlock
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

  /// Parse an Interlock status message
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // Format: <"timeout", value> <"acc_txreq_enable", 1|0> <"rca_txreq_enable", 1|0> <"acc_txreq_polarity", 1|0> <"rca_txreq_polarity", 1|0>
    //              <"tx1_enabled", 1|0> <"tx1_delay", value> <"tx2_enabled", 1|0> <"tx2_delay", value> <"tx3_enabled", 1|0> <"tx3_delay", value>
    //              <"acc_tx_enabled", 1|0> <"acc_tx_delay", value> <"tx_delay", value>
    //      OR
    // Format: <"state", value> <"tx_allowed", 1|0>
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = Token(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .accTxEnabled:
        _api.update(self, property: &_accTxEnabled, value: property.value.bValue(), key: "accTxEnabled")

      case .accTxDelay:
        _api.update(self, property: &_accTxDelay, value: property.value.iValue(), key: "accTxDelay")

      case .accTxReqEnabled:
         _api.update(self, property: &_accTxReqEnabled, value: property.value.bValue(), key: "accTxReqEnabled")

      case .accTxReqPolarity:
       _api.update(self, property: &_accTxReqPolarity, value: property.value.bValue(), key: "accTxReqPolarity")

      case .amplifier:
        _api.update(self, property: &_amplifier, value: property.value, key: "amplifier")
        
      case .rcaTxReqEnabled:
        _api.update(self, property: &_rcaTxReqEnabled, value: property.value.bValue(), key: "rcaTxReqEnabled")

      case .rcaTxReqPolarity:
         _api.update(self, property: &_rcaTxReqPolarity, value: property.value.bValue(), key: "rcaTxReqPolarity")

      case .reason:
        _api.update(self, property: &_reason, value: property.value, key: "reason")

      case .source:
        _api.update(self, property: &_source, value: property.value, key: "source")

      case .state:
        _api.update(self, property: &_state, value: property.value, key: "state")

      case .timeout:
        _api.update(self, property: &_timeout, value: property.value.iValue(), key: "timeout")

      case .txAllowed:
        _api.update(self, property: &_txAllowed, value: property.value.bValue(), key: "txAllowed")

      case .txDelay:
        _api.update(self, property: &_txDelay, value: property.value.iValue(), key: "txDelay")

      case .tx1Delay:
        _api.update(self, property: &_tx1Delay, value: property.value.iValue(), key: "tx1Delay")

      case .tx1Enabled:
        _api.update(self, property: &_tx1Enabled, value: property.value.bValue(), key: "tx1Enabled")

      case .tx2Delay:
        _api.update(self, property: &_tx2Delay, value: property.value.iValue(), key: "tx2Delay")

      case .tx2Enabled:
        _api.update(self, property: &_tx2Enabled, value: property.value.bValue(), key: "tx2Enabled")

      case .tx3Delay:
        _api.update(self, property: &_tx3Delay, value: property.value.iValue(), key: "tx3Delay")

      case .tx3Enabled:
        _api.update(self, property: &_tx3Enabled, value: property.value.bValue(), key: "tx3Enabled")
      }
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Interlock Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Interlock tokens
// --------------------------------------------------------------------------------

extension Interlock {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _accTxEnabled: Bool {
    get { return _q.sync { __accTxEnabled } }
    set { _q.sync(flags: .barrier) { __accTxEnabled = newValue } } }
  
  internal var _accTxDelay: Int {
    get { return _q.sync { __accTxDelay } }
    set { _q.sync(flags: .barrier) { __accTxDelay = newValue } } }
  
  internal var _accTxReqEnabled: Bool {
    get { return _q.sync { __accTxReqEnabled } }
    set { _q.sync(flags: .barrier) { __accTxReqEnabled = newValue } } }
  
  internal var _accTxReqPolarity: Bool {
    get { return _q.sync { __accTxReqPolarity } }
    set { _q.sync(flags: .barrier) { __accTxReqPolarity = newValue } } }
  
  internal var _amplifier: String {
    get { return _q.sync { __amplifier } }
    set { _q.sync(flags: .barrier) { __amplifier = newValue } } }
  
  internal var _rcaTxReqEnabled: Bool {
    get { return _q.sync { __rcaTxReqEnabled } }
    set { _q.sync(flags: .barrier) { __rcaTxReqEnabled = newValue } } }
  
  internal var _rcaTxReqPolarity: Bool {
    get { return _q.sync { __rcaTxReqPolarity } }
    set { _q.sync(flags: .barrier) { __rcaTxReqPolarity = newValue } } }
  
  internal var _reason: String {
    get { return _q.sync { __reason } }
    set { _q.sync(flags: .barrier) { __reason = newValue } } }
  
  internal var _source: String {
    get { return _q.sync { __source } }
    set { _q.sync(flags: .barrier) { __source = newValue } } }
  
  internal var _state: String {
    get { return _q.sync { __state } }
    set { _q.sync(flags: .barrier) { __state = newValue } } }
  
  internal var _timeout: Int {
    get { return _q.sync { __timeout } }
    set { _q.sync(flags: .barrier) { __timeout = newValue } } }
  
  internal var _txAllowed: Bool {
    get { return _q.sync { __txAllowed } }
    set { _q.sync(flags: .barrier) { __txAllowed = newValue } } }
  
  internal var _txDelay: Int {
    get { return _q.sync { __txDelay } }
    set { _q.sync(flags: .barrier) { __txDelay = newValue } } }
  
  internal var _tx1Delay: Int {
    get { return _q.sync { __tx1Delay } }
    set { _q.sync(flags: .barrier) { __tx1Delay = newValue } } }
  
  internal var _tx1Enabled: Bool {
    get { return _q.sync { __tx1Enabled } }
    set { _q.sync(flags: .barrier) { __tx1Enabled = newValue } } }
  
  internal var _tx2Delay: Int {
    get { return _q.sync { __tx2Delay } }
    set { _q.sync(flags: .barrier) { __tx2Delay = newValue } } }
  
  internal var _tx2Enabled: Bool {
    get { return _q.sync { __tx2Enabled } }
    set { _q.sync(flags: .barrier) { __tx2Enabled = newValue } } }
  
  internal var _tx3Delay: Int {
    get { return _q.sync { __tx3Delay } }
    set { _q.sync(flags: .barrier) { __tx3Delay = newValue } } }
  
  internal var _tx3Enabled: Bool {
    get { return _q.sync { __tx3Enabled } }
    set { _q.sync(flags: .barrier) { __tx3Enabled = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  @objc dynamic public var reason: String {
    return _reason }
  
  @objc dynamic public var source: String {
    return _source }
  
  @objc dynamic public var state: String {
    return _state }
  
  @objc dynamic public var txAllowed: Bool {
    return _txAllowed }
  
  @objc dynamic public var txDelay: Int {
    return _txDelay }
  
  // ----------------------------------------------------------------------------
  // MARK: - Interlock tokens
  
  internal enum Token: String {
    case accTxEnabled       = "acc_tx_enabled"
    case accTxDelay         = "acc_tx_delay"
    case accTxReqEnabled    = "acc_txreq_enable"
    case accTxReqPolarity   = "acc_txreq_polarity"
    case amplifier
    case rcaTxReqEnabled    = "rca_txreq_enable"
    case rcaTxReqPolarity   = "rca_txreq_polarity"
    case reason
    case source
    case state
    case timeout
    case txAllowed          = "tx_allowed"
    case txDelay            = "tx_delay"
    case tx1Enabled         = "tx1_enabled"
    case tx1Delay           = "tx1_delay"
    case tx2Enabled         = "tx2_enabled"
    case tx2Delay           = "tx2_delay"
    case tx3Enabled         = "tx3_enabled"
    case tx3Delay           = "tx3_delay"
  }
}
