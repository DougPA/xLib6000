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
//              - Static command prefix properties
//              - Public class methods that send Commands to the Radio (hardware)
//              - Public instance methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension AudioStream {
  
  static let kCmd                           = "audio stream "               // Command prefixes
  static let kStreamCreateCmd               = "stream create "
  static let kStreamRemoveCmd               = "stream remove "

  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands to the Radio (hardware)
  
  /// Create an Audio Stream
  ///
  /// - Parameters:
  ///   - channel:            DAX channel number
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public class func create(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a Stream
    return Api.sharedInstance.sendWithCheck(kStreamCreateCmd + "dax" + "=\(channel)", replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send Commands to the Radio (hardware)
  
  /// Remove this Audio Stream
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func remove(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to remove a Stream
    return Api.sharedInstance.sendWithCheck(AudioStream.kStreamRemoveCmd + "\(id.hex)", replyTo: callback)
  }

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
