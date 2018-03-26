//
//  IqStreamCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - IqStream Class extensions
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension IqStream {
  
  //
  //  NOTE:   IqStream Commands are in the following format:
  //
  //              dax iq <Channel> <valueName>=<value>
  //
  
  static let kCmd                           = "dax iq "                     // Command prefixes
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set an IQ Stream property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func iqCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(IqStream.kCmd + "\(_daxIqChannel) " + token.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  @objc dynamic public var rate: Int {
    get { return _rate }
    set {
      if _rate != newValue {
        if newValue == 24000 || newValue == 48000 || newValue == 96000 || newValue == 192000 {
          _rate = newValue
          iqCmd( .rate, newValue)
        }
      }
    }
  }
}
