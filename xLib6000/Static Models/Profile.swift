//
//  Profile.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import os

// --------------------------------------------------------------------------------
// MARK: - Profile Class implementation
//
//      creates a Profiles instance to be used by a Client to support the
//      processing of the profiles. Profile objects are added, removed and
//      updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public typealias ProfileString              = String

public final class Profile                  : NSObject, StaticModel {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = OSLog(subsystem: Api.kBundleIdentifier, category: "Profile")
  private let _q                            : DispatchQueue                 // Q for object synchronization

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __globalProfileSelection      = ""                            // Global profile name
  private var __micProfileSelection         = ""                            // Mic profile name
  private var __txProfileSelection          = ""                            // TX profile name
  //
  private var _globalProfileList            = [ProfileString]()             // Array of Global Profiles
  private var _micProfileList               = [ProfileString]()             // Array of Mic Profiles
  private var _txProfileList                = [ProfileString]()             // Array of Tx Profiles
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Profile
  ///
  /// - Parameters:
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
  func parseProperties(_ properties: KeyValuesArray) {
    //              <-properties[0]->     <--- properties[1] (if any) --->
    //     format:  <global list, "">     <value, "">^<value, "">^...<value, "">^
    //     format:  <global current, "">  <value, "">
    //     format:  <tx list, "">         <value, "">^<value, "">^...<value, "">^
    //     format:  <tx current, "">      <value, "">
    //     format:  <mic list, "">        <value, "">^<value, "">^...<value, "">^
    //     format:  <mic current, "">     <value, "">

    // determine the type of Profile status
    if let token = Token(rawValue: properties[0].key) {
      
      switch token {
        
      case .globalList:
        willChangeValue(for: \.globalProfileList)
        _globalProfileList = Array(properties[1].key.valuesArray( delimiter: "^" ).dropLast())
        didChangeValue(for: \.globalProfileList)

      case .globalSelection:
        willChangeValue(for: \.globalProfileSelection)
        _globalProfileSelection = (properties.count == 2 ? properties[1].key : "")
        didChangeValue(for: \.globalProfileSelection)

      case .micList:
        willChangeValue(for: \.micProfileList)
        _micProfileList = Array(properties[1].key.valuesArray( delimiter: "^" ).dropLast())
        didChangeValue(for: \.micProfileList)

      case .micSelection:
        willChangeValue(for: \.micProfileSelection)
        _micProfileSelection = (properties.count == 2 ? properties[1].key : "")
        didChangeValue(for: \.micProfileSelection)

      case .txList:
        willChangeValue(for: \.txProfileList)
        _txProfileList = Array(properties[1].key.valuesArray( delimiter: "^" ).dropLast())
        didChangeValue(for: \.txProfileList)

      case .txSelection:
        willChangeValue(for: \.txProfileSelection)
        _txProfileSelection = (properties.count == 2 ? properties[1].key : "")
        didChangeValue(for: \.txProfileSelection)
      }
    } else {
      // unknown type
      os_log("Unknown profile = %{public}@, %{public}@", log: _log, type: .default, properties[0].key, properties[1].key)
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
  internal var _globalProfileSelection: String {
    get { return _q.sync { __globalProfileSelection } }
    set { _q.sync(flags: .barrier) { __globalProfileSelection = newValue } } }
  
  internal var _micProfileSelection: String {
    get { return _q.sync { __micProfileSelection } }
    set { _q.sync(flags: .barrier) { __micProfileSelection = newValue } } }
  
  internal var _txProfileSelection: String {
    get { return _q.sync { __txProfileSelection } }
    set { _q.sync(flags: .barrier) { __txProfileSelection = newValue } } }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  @objc dynamic public var globalProfileList: [ProfileString] {
    get { return _q.sync { _globalProfileList } }
    set { _q.sync(flags: .barrier) { _globalProfileList = newValue } } }
  
  @objc dynamic public var micProfileList: [ProfileString] {
    get { return _q.sync { _micProfileList } }
    set { _q.sync(flags: .barrier) { _micProfileList = newValue } } }
  
  @objc dynamic public var txProfileList: [ProfileString] {
    get { return _q.sync { _txProfileList } }
    set { _q.sync(flags: .barrier) { _txProfileList = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Profile Tokens
  
  public enum Token: String {
    case globalList       = "global list"
    case globalSelection  = "global current"
    case micList          = "mic list"
    case micSelection     = "mic current"
    case txList           = "tx list"
    case txSelection      = "tx current"
  }
}
