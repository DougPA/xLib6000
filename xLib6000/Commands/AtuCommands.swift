//
//  AtuCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Atu Class extensions
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Atu {
  
  //
  //  NOTE:   Atu Commands are in one of the following formats:
  //
  //              atu clear
  //              atu start
  //              atu bypass
  //              atu set <valueName>=<value>
  //
  
  static let kClearCmd                      = "atu clear"                   // Command prefixes
  static let kStartCmd                      = "atu start"
  static let kBypassCmd                     = "atu bypass"
  static let kSetCmd                        = "atu set "
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set an ATU property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func atuCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Atu.kSetCmd + token.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  @objc dynamic public var memoriesEnabled: Bool {
    get {  return _memoriesEnabled }
    set { if _memoriesEnabled != newValue { _memoriesEnabled = newValue ; atuCmd( .memoriesEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var enabled: Bool {
    get {  return _enabled }
    set { if _enabled != newValue { _enabled = newValue ; atuCmd( .enabled, newValue.asNumber()) } } }
}

