//
//  ProfileCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Profile Class extensions
//              - Static command prefix properties
//              - Public instance methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Profile {
  
  static let kCmd                           = "profile "                    // Command prefixes
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods that send Commands to the Radio (hardware)

  /// Delete a Global profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func delete(_ token: Profile.Token, name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to delete the named Global Profile
    Api.sharedInstance.send(Profile.kCmd + token.rawValue + " delete \"" + name + "\"", replyTo: callback)
  }
  /// Save a Global profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func save(_ token: Profile.Token, name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to save the named Global Profile
    Api.sharedInstance.send(Profile.kCmd + token.rawValue + " save \"" + name + "\"", replyTo: callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a Profile property on the Radio
  ///
  /// - Parameters:
  ///   - token:      a String
  ///   - value:      the new value
  ///
  private func profileCmd(_ token: String, _ value: Any) {
    // NOTE: commands use this format when the Token received does not match the Token sent
    //      e.g. see EqualizerCommands.swift where "63hz" is received vs "63Hz" must be sent
    Api.sharedInstance.send(Profile.kCmd + token + " load \"\(value)\"")
  }
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var globalProfileSelection: String {
    get {  return _globalProfileSelection }
    set { if _globalProfileSelection != newValue { _globalProfileSelection = newValue ; profileCmd( "global", newValue) } } }
  
  @objc dynamic public var micProfileSelection: String {
    get {  return _micProfileSelection }
    set { if _micProfileSelection != newValue { _micProfileSelection = newValue ; profileCmd( "mic", newValue) } } }
  
  @objc dynamic public var txProfileSelection: String {
    get {  return _txProfileSelection }
    set { if _txProfileSelection != newValue { _txProfileSelection = newValue  ; profileCmd( "tx", newValue) } } }
  
}
