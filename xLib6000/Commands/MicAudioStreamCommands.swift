//
//  MicAudioStreamCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - MicAudioStream Class extensions
//              - Static command prefix properties
//              - Public class methods that send Commands to the Radio (hardware)
//              - Public instance methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension MicAudioStream {

  static let kMicStreamCreateCmd            = "stream create daxmic"
  static let kStreamRemoveCmd               = "stream remove "

  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands to the Radio (hardware)
  
  /// Create a Mic Audio Stream
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public class func create(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a Stream
    return Api.sharedInstance.sendWithCheck(kMicStreamCreateCmd, replyTo: callback)
  }
  /// Request a List of Mic sources
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public class func listRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio for a list of Mic Sources
    Api.sharedInstance.send(Api.Command.micList.rawValue, replyTo: callback == nil ? Api.sharedInstance.radio!.defaultReplyHandler : callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send Commands to the Radio (hardware)
  
  /// Remove this Mic Audio Stream
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Stream
    Api.sharedInstance.send(MicAudioStream.kStreamRemoveCmd + "\(id.hex)", replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // ----- NONE -----
}
