//
//  Profile.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import os

public typealias ProfileId = String

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

  public static let kGlobal                 = "global"
  public static let kMic                    = "mic"
  public static let kTx                     = "tx"

  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : ProfileId!

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = OSLog(subsystem: Api.kBundleIdentifier, category: "Profile")
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio (hardware)

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __list           = [ProfileString]()             // list of Profile names
  private var __selection      : ProfileId = ""                // selected Profile name
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a Profile status message
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray
  ///   - radio:              the current Radio class
  ///   - queue:              a parse Queue for the object
  ///   - inUse:              false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    
    let components = keyValues[0].key.split(separator: " ")
    
    // get the Profile Id
    let profileId = String(components[0])
    
    // remove the Id from the KeyValues
    var adjustedKeyValues = keyValues
    adjustedKeyValues[0].key = String(components[1])
    
    // does the Profile exist?
    if  radio.profiles[profileId] == nil {
      
      // NO, create a new Profile & add it to the Profiles collection
      radio.profiles[profileId] = Profile(id: profileId, queue: queue)
    }
    // pass the key values to Profile for parsing (dropping the Id)
    radio.profiles[profileId]!.parseProperties( adjustedKeyValues )
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Profile
  ///
  /// - Parameters:
  ///   - id:                 Concurrent queue
  ///   - queue:              Concurrent queue
  ///
  public init(id: ProfileId, queue: DispatchQueue) {
   self.id = id
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

    // check for unknown keys
    guard let token = Token(rawValue: properties[0].key) else {
      // unknown Key, log it and ignore the Key
      os_log("Unknown %{public}@ Profile token - %{public}@", log: _log, type: .default, id, properties[0].key)
      
      return
    }
    // Known keys, in alphabetical order
    if token == Profile.Token.list {
      
      willChangeValue(for: \.list)
      _list = Array(properties[1].key.valuesArray( delimiter: "^" ).dropLast())
      didChangeValue(for: \.list)
    }
    
    if token  == Profile.Token.selection {
      
      willChangeValue(for: \.selection)
      _selection = (properties.count > 1 ? properties[1].key : "")
      didChangeValue(for: \.selection)
    }
    // is the Profile initialized?
    if !_initialized && _list.count > 0 && _selection != "" {
      
      // YES, the Radio (hardware) has acknowledged this Panadapter
      _initialized = true
      
      // notify all observers
      NC.post(.profileHasBeenAdded, object: self as Any?)
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
  internal var _list: [ProfileString] {
    get { return _q.sync { __list } }
    set { _q.sync(flags: .barrier) { __list = newValue } } }

  internal var _selection: ProfileId {
    get { return _q.sync { __selection } }
    set { _q.sync(flags: .barrier) { __selection = newValue } } }

  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  @objc dynamic public var list: [ProfileString] {
    return _list }
  
  // ----------------------------------------------------------------------------
  // MARK: - Profile Tokens
  
  public enum Token: String {
    case list       = "list"
    case selection  = "current"
  }
}
