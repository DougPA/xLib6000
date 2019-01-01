//
//  TxAudioStreamCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - TxAudioStream Class extensions
//              - Static command prefix properties
//              - Public class methods that send Commands to the Radio (hardware)
//              - Public instance methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension TxAudioStream {
  
  static let kCmd                           = "dax "                        // Command prefixes
  static let kStreamCreateCmd               = "stream create "
  static let kStreamRemoveCmd               = "stream remove "

  // ----------------------------------------------------------------------------
  // MARK: - Public Class methods that send Commands to the Radio (hardware)

  /// Create a Tx Audio Stream
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public class func create(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a Stream
    return Api.sharedInstance.sendWithCheck(kStreamCreateCmd + "daxtx", replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods that send Commands to the Radio (hardware)

  /// Remove this Tx Audio Stream
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove a Stream
    Api.sharedInstance.send(TxAudioStream.kStreamRemoveCmd + "\(id.hex)", replyTo: callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a TxAudioStream property on the Radio
  ///
  /// - Parameters:
  ///   - id:         the TxAudio Stream Id
  ///   - value:      the new value
  ///
  private func txAudioCmd(_ value: Any) {
    
    Api.sharedInstance.send(TxAudioStream.kCmd + "tx" + " \(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var transmit: Bool {
    get { return _transmit  }
    set { if _transmit != newValue { _transmit = newValue ; txAudioCmd( newValue.asNumber) } } }
}
