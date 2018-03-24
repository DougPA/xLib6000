//
//  Profile.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Profile Class implementation
//
//      creates a Profiles instance to be used by a Client to support the
//      processing of the profiles
//
// --------------------------------------------------------------------------------

public typealias ProfileString              = String

public final class Profile                  : NSObject, PropertiesParser {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __currentGlobalProfile        = ""                            // Global profile name
  private var __currentMicProfile           = ""                            // Mic profile name
  private var __currentTxProfile            = ""                            // TX profile name
  //
  private var _profiles                     = [Token: [ProfileString]]()    // Dictionary of Profiles
  //                                                                                              
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Profile
  ///
  /// - Parameters:
  ///   - radio:              parent Radio class
  ///   - queue:              Concurrent queue
  ///
  public init(queue: DispatchQueue) {
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse a Profile status message
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  internal func parseProperties(_ properties: KeyValuesArray) {
    // Format:  <profileType, > <"list",value^value...^value>
    //      OR
    // Format:  <profileType, > <"current", value>
    
    let values = properties[1].value.valuesArray( delimiter: "^" )
    
    // determine the type of Profile & save it
    if let token = Token(rawValue: properties[0].key), let subToken = SubToken(rawValue: properties[1].key) {
      
      switch token {
        
      case .global:
        switch subToken {
        case .list:
          // Global List
          willChangeValue(forKey: "profiles")
          _profiles[.global] = values
          didChangeValue(forKey: "profiles")
        
        case .current:
          // Global Current
          willChangeValue(forKey: "currentGlobalProfile")
          _currentGlobalProfile = values[0]
          didChangeValue(forKey: "currentGlobalProfile")
        }
        
      case .mic:
        switch subToken {
        case .list:
          // Mic List
          willChangeValue(forKey: "profiles")
          _profiles[.mic] = values
          didChangeValue(forKey: "profiles")
        
        case .current:
          // Mic Current
          willChangeValue(forKey: "currentMicProfile")
          _currentMicProfile = values[0]
          didChangeValue(forKey: "currentMicProfile")
        }
        
      case .tx:
        switch subToken {
        case .list:
          // Tx List
          willChangeValue(forKey: "profiles")
          _profiles[.tx] = values
          didChangeValue(forKey: "profiles")
        
        case .current:
          // Tx Current
          willChangeValue(forKey: "currentTxProfile")
          _currentTxProfile = values[0]
          didChangeValue(forKey: "currentTxProfile")
        }
      }
    } else {
      // unknown type
      Log.sharedInstance.msg("Unknown profile - \(properties[0].key), \(properties[1].key)", level: .debug, function: #function, file: #file, line: #line)
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Profile Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Profile tokens
// --------------------------------------------------------------------------------

extension Profile {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _currentGlobalProfile: String {
    get { return _q.sync { __currentGlobalProfile } }
    set { _q.sync(flags: .barrier) { __currentGlobalProfile = newValue } } }
  
  internal var _currentMicProfile: String {
    get { return _q.sync { __currentMicProfile } }
    set { _q.sync(flags: .barrier) { __currentMicProfile = newValue } } }
  
  internal var _currentTxProfile: String {
    get { return _q.sync { __currentTxProfile } }
    set { _q.sync(flags: .barrier) { __currentTxProfile = newValue } } }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  public var profiles: [Token: [ProfileString]] {
    get { return _q.sync { _profiles } }
    set { _q.sync(flags: .barrier) { _profiles = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Profile Tokens
  
  public enum Token: String {
    case global
    case mic
    case tx
  }
  internal enum SubToken: String {
    case current
    case list
  }
}
