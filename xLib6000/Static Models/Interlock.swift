//
//  Interlock.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import os

/// Interlock Class implementation
///
///      creates an Interlock instance to be used by a Client to support the
///      processing of interlocks. Interlock objects are added, removed and
///      updated by the incoming TCP messages.
///
public final class Interlock                : NSObject, StaticModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kCmd                           = "interlock "

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = OSLog(subsystem: Api.kBundleIdentifier, category: "Interlock")
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
  // MARK: - Protocol instance methods

  /// Parse an Interlock status message
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
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
        os_log("Unknown Interlock token = %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .accTxEnabled:
        willChangeValue(for: \.accTxEnabled)
        _accTxEnabled = property.value.bValue
        didChangeValue(for: \.accTxEnabled)

      case .accTxDelay:
        willChangeValue(for: \.accTxDelay)
        _accTxDelay = property.value.iValue
        didChangeValue(for: \.accTxDelay)

      case .accTxReqEnabled:
          willChangeValue(for: \.accTxReqEnabled)
         _accTxReqEnabled = property.value.bValue
         didChangeValue(for: \.accTxReqEnabled)

      case .accTxReqPolarity:
       willChangeValue(for: \.accTxReqPolarity)
       _accTxReqPolarity = property.value.bValue
       didChangeValue(for: \.accTxReqPolarity)

      case .amplifier:
        willChangeValue(for: \.amplifier)
        _amplifier = property.value
        didChangeValue(for: \.amplifier)

      case .rcaTxReqEnabled:
        willChangeValue(for: \.rcaTxReqEnabled)
        _rcaTxReqEnabled = property.value.bValue
        didChangeValue(for: \.rcaTxReqEnabled)

      case .rcaTxReqPolarity:
         willChangeValue(for: \.rcaTxReqPolarity)
         _rcaTxReqPolarity = property.value.bValue
         didChangeValue(for: \.rcaTxReqPolarity)

      case .reason:
        willChangeValue(for: \.reason)
        _reason = property.value
        didChangeValue(for: \.reason)

      case .source:
        willChangeValue(for: \.source)
        _source = property.value
        didChangeValue(for: \.source)

      case .state:
        willChangeValue(for: \.state)
        _state = property.value
        didChangeValue(for: \.state)
        
        // determine if a Mox change is needed
        _api.radio!.stateChange(_state)

      case .timeout:
        willChangeValue(for: \.timeout)
        _timeout = property.value.iValue
        didChangeValue(for: \.timeout)

      case .txAllowed:
        willChangeValue(for: \.txAllowed)
        _txAllowed = property.value.bValue
        didChangeValue(for: \.txAllowed)

      case .txDelay:
        willChangeValue(for: \.txDelay)
        _txDelay = property.value.iValue
        didChangeValue(for: \.txDelay)

      case .tx1Delay:
        willChangeValue(for: \.tx1Delay)
        _tx1Delay = property.value.iValue
        didChangeValue(for: \.tx1Delay)

      case .tx1Enabled:
        willChangeValue(for: \.tx1Enabled)
        _tx1Enabled = property.value.bValue
        didChangeValue(for: \.tx1Enabled)

      case .tx2Delay:
        willChangeValue(for: \.tx2Delay)
        _tx2Delay = property.value.iValue
        didChangeValue(for: \.tx2Delay)

      case .tx2Enabled:
        willChangeValue(for: \.tx2Enabled)
        _tx2Enabled = property.value.bValue
        didChangeValue(for: \.tx2Enabled)

      case .tx3Delay:
        willChangeValue(for: \.tx3Delay)
        _tx3Delay = property.value.iValue
        didChangeValue(for: \.tx3Delay)

      case .tx3Enabled:
        willChangeValue(for: \.tx3Enabled)
        _tx3Enabled = property.value.bValue
        didChangeValue(for: \.tx3Enabled)
      }
    }
  }
}

extension Interlock {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
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
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var reason: String {
    return _reason }
  
  @objc dynamic public var source: String {
    return _source }

  @objc dynamic public var amplifier: String {
    return _amplifier }

  @objc dynamic public var state: String {
    return _state }
  
  @objc dynamic public var txAllowed: Bool {
    return _txAllowed }
    
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
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
  /// States
  ///
  internal enum State: String {
    case receive            = "RECEIVE"
    case ready              = "READY"
    case notReady           = "NOT_READY"
    case pttRequested       = "PTT_REQUESTED"
    case transmitting       = "TRANSMITTING"
    case txFault            = "TX_FAULT"
    case timeout            = "TIMEOUT"
    case stuckInput         = "STUCK_INPUT"
    case unKeyRequested     = "UNKEY_REQUESTED"
  }
  /// Sources
  ///
  internal enum PttSource: String {
    case software           = "SW"
    case mic                = "MIC"
    case acc                = "ACC"
    case rca                = "RCA"
  }
  /// Reasons
  ///
  internal enum Reasons: String {
    case rcaTxRequest       = "RCA_TXREQ"
    case accTxRequest       = "ACC_TXREQ"
    case badMode            = "BAD_MODE"
    case tooFar             = "TOO_FAR"
    case outOfBand          = "OUT_OF_BAND"
    case paRange            = "PA_RANGE"
    case clientTxInhibit    = "CLIENT_TX_INHIBIT"
    case xvtrRxOnly         = "XVTR_RX_OLY"
  }
}
