//
//  OpusCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Opus Class extensions
//              - Static command prefix properties
//              - Public instance methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Opus {
  
  static let kCmd                           = "remote_audio "               // Command prefixes
  static let kStreamCreateCmd               = "stream create "
  static let kStreamRemoveCmd               = "stream remove "

  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send Commands to the Radio (hardware)
  
  /// Turn Opus Rx On/Off
  ///
  /// - Parameters:
  ///   - value:              On/Off
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remoteRxAudioRequest(_ value: Bool, callback: ReplyHandler? = nil) {
    
    // tell the Radio to enable Opus Rx
    Api.sharedInstance.send(Opus.kCmd + Opus.Token.remoteRxOn.rawValue + " \(value.asNumber())", replyTo: callback)
  }
  /// Remove this Opus Stream
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Stream
    Api.sharedInstance.send(Opus.kStreamRemoveCmd + "0x\(id)", replyTo: callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set an Opus property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func opusCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Opus.kCmd + token.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var remoteRxOn: Bool {
    get { return _remoteRxOn }
    set { if _remoteRxOn != newValue { _remoteRxOn = newValue ; opusCmd( .remoteRxOn, newValue.asNumber()) } } }
  
  @objc dynamic public var remoteTxOn: Bool {
    get { return _remoteTxOn }
    set { if _remoteTxOn != newValue { _remoteTxOn = newValue ; opusCmd( .remoteTxOn, newValue.asNumber()) } } }
}
