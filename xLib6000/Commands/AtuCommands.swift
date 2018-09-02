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
//              - Static command prefix properties
//              - Public methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Atu {
  
  static let kClearCmd                      = "atu clear"                   // Command prefixes
  static let kStartCmd                      = "atu start"
  static let kBypassCmd                     = "atu bypass"
  static let kCmd                           = "atu "
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods that send Commands to the Radio (hardware)

  /// Clear the ATU
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func atuClear(callback: ReplyHandler? = nil) {
    
    // tell the Radio to clear the ATU
    Api.sharedInstance.send(Atu.kClearCmd, replyTo: callback)
  }
  /// Start the ATU
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func atuStart(callback: ReplyHandler? = nil) {
    
    // tell the Radio to start the ATU
    Api.sharedInstance.send(Atu.kStartCmd, replyTo: callback)
  }
  /// Bypass the ATU
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func atuBypass(callback: ReplyHandler? = nil) {
    
    // tell the Radio to bypass the ATU
    Api.sharedInstance.send(Atu.kBypassCmd, replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set an ATU property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func atuCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Atu.kCmd + token.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  @objc dynamic public var memoriesEnabled: Bool {
    get {  return _memoriesEnabled }
    set { if _memoriesEnabled != newValue { _memoriesEnabled = newValue ; atuCmd( .memoriesEnabled, newValue.asNumber()) } } }
  
//  @objc dynamic public var enabled: Bool {
//    get {  return _enabled }
//    set { if _enabled != newValue { _enabled = newValue ; atuCmd( .enabled, newValue.asNumber()) } } }
  @objc dynamic public var enabled: Bool {
      return _enabled }
}

