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
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Profile {
  
  //
  //  NOTE:   Profile Commands are in the following format:
  //
  //              profile load "profileName"
  //
  
  static let kCmd                           = "profile "                    // Command prefixes
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a Profile property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func profileCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Profile.kCmd + token.rawValue + " load \"\(value)\"")
  }
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var currentGlobalProfile: String {
    get {  return _currentGlobalProfile }
    set { if _currentGlobalProfile != newValue { _currentGlobalProfile = newValue ; profileCmd( .global, newValue) } } }
  
  @objc dynamic public var currentMicProfile: String {
    get {  return _currentMicProfile }
    set { if _currentMicProfile != newValue { _currentMicProfile = newValue ; profileCmd( .mic, newValue) } } }
  
  @objc dynamic public var currentTxProfile: String {
    get {  return _currentTxProfile }
    set { if _currentTxProfile != newValue { _currentTxProfile = newValue  ; profileCmd( .tx, newValue) } } }
  
}
