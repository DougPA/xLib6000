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
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension TxAudioStream {
  
  //
  //  NOTE:   TxAudioStream Commands are in the following format:
  //
  //              dax <valueName> <value>
  //
  
  static let kCmd                           = "dax "                        // Command prefixes
  
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
    set { if _transmit != newValue { _transmit = newValue ; txAudioCmd( newValue.asNumber()) } } }
}
