//
//  Atu.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import os

// --------------------------------------------------------------------------------
// MARK: - Atu Class implementation
//
//      creates an Atu instance to be used by a Client to support the
//      processing of the Antenna Tuning Unit (if installed). Atu objects are
//      added, removed and updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Atu                      : NSObject, StaticModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = OSLog(subsystem: Api.kBundleIdentifier, category: "Atu")
  private let _q                            : DispatchQueue                 // Q for object synchronization

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __enabled                     = false                         //
  private var __memoriesEnabled             = false                         //
  private var __status                      = Status.none.rawValue          //
  private var __usingMemories               = false                         //
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Atu
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

  /// Parse an Atu status message
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // Format: <"status", value> <"memories_enabled", 1|0> <"using_mem", 1|0>
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = Token(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        os_log("Unknown Atu token = %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .enabled:
        willChangeValue(for: \.enabled)
        _enabled = property.value.bValue
        didChangeValue(for: \.enabled)

      case .memoriesEnabled:
        willChangeValue(for: \.memoriesEnabled)
        _memoriesEnabled = property.value.bValue
        didChangeValue(for: \.memoriesEnabled)

      case .status:
        willChangeValue(for: \.status)
        _status = property.value
        didChangeValue(for: \.status)

      case .usingMemories:
        willChangeValue(for: \.usingMemories)
        _usingMemories = property.value.bValue
        didChangeValue(for: \.usingMemories)
      }
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Atu Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Atu tokens
// --------------------------------------------------------------------------------

extension Atu {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _enabled: Bool {
    get { return _q.sync { __enabled } }
    set { _q.sync(flags: .barrier) { __enabled = newValue } } }
  
  internal var _memoriesEnabled: Bool {
    get { return _q.sync { __memoriesEnabled } }
    set { _q.sync(flags: .barrier) { __memoriesEnabled = newValue } } }
  
  internal var _status: String {
    get { return _q.sync { __status } }
    set { _q.sync(flags: .barrier) { __status = newValue } } }
  
  internal var _usingMemories: Bool {
    get { return _q.sync { __usingMemories } }
    set { _q.sync(flags: .barrier) { __usingMemories = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  @objc dynamic public var status: String {
    var value = ""
    guard let token = Status(rawValue: _status) else { return "Unknown" }
    switch token {
    case .none, .tuneNotStarted:
      break
    case .tuneInProgress:
      value = "Tuning"
    case .tuneBypass:
      value = "Success Byp"
    case .tuneSuccessful:
      value = "Success"
    case .tuneOK:
      value = "OK"
    case .tuneFailBypass:
      value = "Fail Byp"
    case .tuneFail:
      value = "Fail"
    case .tuneAborted:
      value = "Aborted"
    case .tuneManualBypass:
      value = "Manual Byp"
    }
    return value }
  
  @objc dynamic public var usingMemories: Bool {
    return _usingMemories }
  
  // ----------------------------------------------------------------------------
  // MARK: - Atu tokens
  
  internal enum Token: String {
    case status
    case enabled          = "atu_enabled"
    case memoriesEnabled  = "memories_enabled"
    case usingMemories    = "using_mem"
  }
  
  internal enum Status: String {
    case none             = "NONE"
    case tuneNotStarted   = "TUNE_NOT_STARTED"
    case tuneInProgress   = "TUNE_IN_PROGRESS"
    case tuneBypass       = "TUNE_BYPASS"
    case tuneSuccessful   = "TUNE_SUCCESSFUL"
    case tuneOK           = "TUNE_OK"
    case tuneFailBypass   = "TUNE_FAIL_BYPASS"
    case tuneFail         = "TUNE_FAIL"
    case tuneAborted      = "TUNE_ABORTED"
    case tuneManualBypass = "TUNE_MANUAL_BYPASS"
  }
}
