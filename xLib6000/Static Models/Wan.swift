//
//  Wan.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Wan Class implementation
///
///      creates a Wan instance to be used by a Client to support the
///      processing of the Wan-related activities. Wan objects are added,
///      removed and updated by the incoming TCP messages.
///
public final class Wan                      : NSObject, StaticModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private let _log                          = Log.sharedInstance

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
  ///   - queue:              Concurrent queue
  ///
  public init(queue: DispatchQueue) {
    self._q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods

  /// Parse a Wan status message
  ///
  ///   PropertiesParser Protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = Token(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        _log.msg( "Unknown Wan token - \(property.key) = \(property.value)", level: .info, function: #function, file: #file, line: #line)

        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .serverConnected:
        willChangeValue(for: \.serverConnected)
        _serverConnected = property.value.bValue
        didChangeValue(for: \.serverConnected)

      case .radioAuthenticated:
        willChangeValue(for: \.radioAuthenticated)
        _radioAuthenticated = property.value.bValue
        didChangeValue(for: \.radioAuthenticated)
      }
    }
  }
}

extension Wan {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _radioAuthenticated: Bool {
    get { return _q.sync { __radioAuthenticated } }
    set { _q.sync(flags: .barrier) { __radioAuthenticated = newValue } } }
  
  internal var _serverConnected: Bool {
    get { return _q.sync { __serverConnected } }
    set { _q.sync(flags: .barrier) { __serverConnected = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var radioAuthenticated: Bool {
    return _radioAuthenticated }
  
  @objc dynamic public var serverConnected: Bool {
    return _serverConnected }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum Token: String {
    case serverConnected = "server_connected"
    case radioAuthenticated = "radio_authenticated"
  }
}
