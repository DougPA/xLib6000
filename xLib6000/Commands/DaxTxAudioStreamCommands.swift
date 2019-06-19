//
//  DaxTxAudioStreaCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Command extension

extension DaxTxAudioStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands

  /// Create a Tx Audio Stream
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public class func create(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a Stream
    return Api.sharedInstance.sendWithCheck("stream create type=dax_tx", replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Instance methods that send Commands

  /// Remove this Tx Audio Stream
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func remove(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to remove this Stream
    if Api.sharedInstance.sendWithCheck("stream remove \(streamId.hex)", replyTo: callback) {
      
      // notify all observers
      NC.post(.daxRxAudioStreamWillBeRemoved, object: self as Any?)
      
      // remove the stream object
      Api.sharedInstance.radio?.daxRxAudioStreams[streamId] = nil
      
      return true
    }
    return false
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a TxAudioStream property on the Radio
  ///
  /// - Parameters:
  ///   - value:      the new value
  ///
  private func txAudioCmd(_ value: Any) {
    
    Api.sharedInstance.send("dax tx" + " \(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties (KVO compliant) that send Commands
  
  @objc dynamic public var isTransmitChannel: Bool {
    get { return _isTransmitChannel  }
    set { if _isTransmitChannel != newValue { _isTransmitChannel = newValue ; txAudioCmd( newValue.as1or0) } } }
}