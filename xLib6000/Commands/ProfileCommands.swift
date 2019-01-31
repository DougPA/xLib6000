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
//              - Public class methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Profile {
  
  static let kCmd                           = "profile "                    // Command prefixes
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Class methods that send Commands to the Radio (hardware)

  /// Delete a Profile entry
  ///
  /// - Parameters:
  ///   - token:              profile type
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func delete(_ type: String, name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to delete the Profile name in the specified Profile type
    Api.sharedInstance.send(Profile.kCmd + type + " delete \"" + name + "\"", replyTo: callback)
  }
  /// Save a Profile entry
  ///
  /// - Parameters:
  ///   - token:              profile type
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func save(_ type: String, name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to save the Profile name in the specified Profile type
    Api.sharedInstance.send(Profile.kCmd + type + " save \"" + name + "\"", replyTo: callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a Profile property on the Radio
  ///
  /// - Parameters:
  ///   - token:      a String
  ///   - value:      the new value
  ///
  private func profileCmd(_ value: Any) {
    // NOTE: commands use this format when the Token received does not match the Token sent
    //      e.g. see EqualizerCommands.swift where "63hz" is received vs "63Hz" must be sent
    Api.sharedInstance.send(Profile.kCmd + id + " load \"\(value)\"")
  }
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var selection: ProfileId {
    get {  return _selection }
    set { if _selection != newValue { _selection = newValue ; profileCmd(newValue) } } }
  
}
