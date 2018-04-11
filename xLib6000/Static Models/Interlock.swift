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

public final class Interlock                : NSObject, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __accTxEnabled                = false                         //
  private var __accTxDelay                  = 0                             //
  private var __accTxReqEnabled             = false                         //
  private var __accTxReqPolarity            = false                         //
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
  ///   - radio:              parent Radio class
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
  internal func parseProperties(_ properties: KeyValuesArray) {
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
        willChangeValue(forKey: "accTxEnabled")
        _accTxEnabled = property.value.bValue()
        didChangeValue(forKey: "accTxEnabled")
        
      case .accTxDelay:
        willChangeValue(forKey: "accTxDelay")
        _accTxDelay = property.value.iValue()
        didChangeValue(forKey: "accTxDelay")
        
      case .accTxReqEnabled:
        willChangeValue(forKey: "accTxReqEnabled")
        _accTxReqEnabled = property.value.bValue()
        didChangeValue(forKey: "accTxReqEnabled")
        
      case .accTxReqPolarity:
        willChangeValue(forKey: "accTxReqPolarity")
        _accTxReqPolarity = property.value.bValue()
        didChangeValue(forKey: "accTxReqPolarity")
        
      case .rcaTxReqEnabled:
        willChangeValue(forKey: "rcaTxReqEnabled")
        _rcaTxReqEnabled = property.value.bValue()
        didChangeValue(forKey: "rcaTxReqEnabled")
        
      case .rcaTxReqPolarity:
        willChangeValue(forKey: "rcaTxReqPolarity")
        _rcaTxReqPolarity = property.value.bValue()
        didChangeValue(forKey: "rcaTxReqPolarity")
        
      case .reason:
        willChangeValue(forKey: "reason")
        _reason = property.value
        didChangeValue(forKey: "reason")
        
      case .source:
        willChangeValue(forKey: "source")
        _source = property.value
        didChangeValue(forKey: "source")
        
      case .state:
        willChangeValue(forKey: "state")
        _state = property.value
        didChangeValue(forKey: "state")
        
      case .timeout:
        willChangeValue(forKey: "timeout")
        _timeout = property.value.iValue()
        didChangeValue(forKey: "timeout")
        
      case .txAllowed:
        willChangeValue(forKey: "txAllowed")
        _txAllowed = property.value.bValue()
        didChangeValue(forKey: "txAllowed")
        
      case .txDelay:
        willChangeValue(forKey: "txDelay")
        _txDelay = property.value.iValue()
        didChangeValue(forKey: "txDelay")
        
      case .tx1Delay:
        willChangeValue(forKey: "tx1Enabled")
        _tx1Delay = property.value.iValue()
        didChangeValue(forKey: "tx1Enabled")
        
      case .tx1Enabled:
        willChangeValue(forKey: "key")
        _tx1Enabled = property.value.bValue()
        didChangeValue(forKey: "key")
        
      case .tx2Delay:
        willChangeValue(forKey: "tx2Delay")
        _tx2Delay = property.value.iValue()
        didChangeValue(forKey: "tx2Delay")
        
      case .tx2Enabled:
        willChangeValue(forKey: "tx2Enabled")
        _tx2Enabled = property.value.bValue()
        didChangeValue(forKey: "tx2Enabled")
        
      case .tx3Delay:
        willChangeValue(forKey: "tx3Delay")
        _tx3Delay = property.value.iValue()
        didChangeValue(forKey: "tx3Delay")
        
      case .tx3Enabled:
        willChangeValue(forKey: "tx3Enabled")
        _tx3Enabled = property.value.bValue()
        didChangeValue(forKey: "tx3Enabled")
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
    case accTxEnabled = "acc_tx_enabled"
    case accTxDelay = "acc_tx_delay"
    case accTxReqEnabled = "acc_txreq_enable"
    case accTxReqPolarity = "acc_txreq_polarity"
    case rcaTxReqEnabled = "rca_txreq_enable"
    case rcaTxReqPolarity = "rca_txreq_polarity"
    case reason
    case source
    case state
    case timeout
    case txAllowed = "tx_allowed"
    case txDelay = "tx_delay"
    case tx1Enabled = "tx1_enabled"
    case tx1Delay = "tx1_delay"
    case tx2Enabled = "tx2_enabled"
    case tx2Delay = "tx2_delay"
    case tx3Enabled = "tx3_enabled"
    case tx3Delay = "tx3_delay"
  }
}
