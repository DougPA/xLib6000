//
//  DaxIqStreamCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Command extension

extension DaxIqStream {

  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands

  /// Create an IQ Stream
  ///
  /// - Parameters:
  ///   - channel:            DAX channel number
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
//  public class func create(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
//
//    return Api.sharedInstance.sendWithCheck(kStreamCreateCmd + "daxiq" + "=\(channel)", replyTo: callback)
//  }
  /// Create an IQ Stream
  ///
  /// - Parameters:
  ///   - channel:            DAX channel number
  ///   - ip:                 ip address
  ///   - port:               port number
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public class func create(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create the Stream
    return Api.sharedInstance.sendWithCheck("stream create type=dax_iq daxiq_channel=\(channel)", replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Instance methods that send Commands

  /// Remove this IQ Stream
  ///
  /// - Parameters:
  ///   - id:                 IQ Stream Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil) {

    // tell the Radio to remove the Stream
    Api.sharedInstance.send("stream remove \(streamId.hex)", replyTo: callback)
  }
  /// Get error ???
  ///
  /// - Parameters:
  ///   - id:                 IQ Stream Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func getError(callback: ReplyHandler? = nil) {
    
    // tell the Radio to ???
    Api.sharedInstance.send("stream get_error \(streamId.hex)", replyTo: callback)
  }
  // ----------------------------------------------------------------------------
  // MARK: - Properties (KVO compliant) that send Commands
  
  @objc dynamic public var rate: Int {
    get { return _rate }
    set {
      if _rate != newValue {
        if newValue == 24000 || newValue == 48000 || newValue == 96000 || newValue == 192000 {
          _rate = newValue
          Api.sharedInstance.send("stream set \(streamId.hex) daxiq_rate=\(_rate)")
        }
      }
    }
  }
}
