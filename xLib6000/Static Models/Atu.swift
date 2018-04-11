//
//  Atu.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Atu Class implementation
//
//      creates an Atu instance to be used by a Client to support the
//      processing of the Antenna Tuning Unit (if installed). Atu objects are
//      added, removed and updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Atu                      : NSObject, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __enabled                     = false                         //
  private var __memoriesEnabled             = false                         //
  private var __status                      = false                         //
  private var __usingMemories               = false                         //
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Atu
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

  /// Parse an Atu status message
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  internal func parseProperties(_ properties: KeyValuesArray) {
    // Format: <"status", value> <"memories_enabled", 1|0> <"using_mem", 1|0>
    
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
        
      case .enabled:
        willChangeValue(forKey: "enabled")
        _enabled = property.value.bValue()
        didChangeValue(forKey: "enabled")
        
      case .memoriesEnabled:
        willChangeValue(forKey: "memoriesEnabled")
        _memoriesEnabled = property.value.bValue()
        didChangeValue(forKey: "memoriesEnabled")
        
      case .status:
        willChangeValue(forKey: "status")
        _status = ( property.value == "present" ? true : false )
        didChangeValue(forKey: "status")
        
      case .usingMemories:
        willChangeValue(forKey: "usingMemories")
        _usingMemories = property.value.bValue()
        didChangeValue(forKey: "usingMemories")
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
  
  internal var _status: Bool {
    get { return _q.sync { __status } }
    set { _q.sync(flags: .barrier) { __status = newValue } } }
  
  internal var _usingMemories: Bool {
    get { return _q.sync { __usingMemories } }
    set { _q.sync(flags: .barrier) { __usingMemories = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  @objc dynamic public var status: Bool {
    return _status }
  
  @objc dynamic public var usingMemories: Bool {
    return _usingMemories }
  
  // ----------------------------------------------------------------------------
  // MARK: - Atu tokens
  
  internal enum Token: String {
    case status
    case enabled = "atu_enabled"
    case memoriesEnabled = "memories_enabled"
    case usingMemories = "using_mem"
  }
}
