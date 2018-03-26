//
//  AudioStreamCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - AudioStream Class extensions
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension AudioStream {
  
  //
  //  NOTE:   AudioStream Commands are in the following format:
  //
  //              audio stream <StreamId> slice <SliceId> <valueName> <value>
  //
  
  static let kCmd                           = "audio stream "               // Command prefixes
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set an Audio Stream property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func audioStreamCmd(_ token: String, _ value: Any) {
    
    Api.sharedInstance.send(AudioStream.kCmd + "\(id.hex) slice \(_slice!.id) " + token + " \(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var rxGain: Int {
    get { return _rxGain  }
    set { if _rxGain != newValue {
      let value = newValue.bound(0, 100)
      if _rxGain != value {
        _rxGain = value
        if _slice != nil { audioStreamCmd( "gain", value) }
      }
      }
    }
  }
}
