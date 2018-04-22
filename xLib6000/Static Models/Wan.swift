//
//  Wan.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Wan Class implementation
//
//      creates a Wan instance to be used by a Client to support the
//      processing of the Wan-related activities. Wan objects are added,
//      removed and updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Wan                      : NSObject, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __radioAuthenticated          = false                         // SmartLink status
  private var __serverConnected             = false                         // SmartLink status
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Wan
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

  /// Parse a Wan status message
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
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
        
      case .serverConnected:
        update(&_serverConnected, value: property.value.bValue(), key: "serverConnected")

      case .radioAuthenticated:
        update(&_radioAuthenticated, value: property.value.bValue(), key: "radioAuthenticated")
      }
    }
  }
  /// Update a property & signal KVO
  ///
  /// - Parameters:
  ///   - property:           the property (mutable)
  ///   - value:              the new value
  ///   - key:                the KVO key
  ///
  private func update<T: Equatable>(_ property: inout T, value: T, key: String) {
    
    // update the property & signal KVO (if needed)
    if property != value {
      willChangeValue(forKey: key)
      property = value
      didChangeValue(forKey: key)
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Wan Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Wan tokens
// --------------------------------------------------------------------------------

extension Wan {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  
  internal var _radioAuthenticated: Bool {
    get { return _q.sync { __radioAuthenticated } }
    set { _q.sync(flags: .barrier) { __radioAuthenticated = newValue } } }
  
  internal var _serverConnected: Bool {
    get { return _q.sync { __serverConnected } }
    set { _q.sync(flags: .barrier) { __serverConnected = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  @objc dynamic public var radioAuthenticated: Bool {
    return _radioAuthenticated }
  
  @objc dynamic public var serverConnected: Bool {
    return _serverConnected }
  
  // ----------------------------------------------------------------------------
  // MARK: - Wan Tokens
  
  internal enum Token: String {
    case serverConnected = "server_connected"
    case radioAuthenticated = "radio_authenticated"
  }
}
