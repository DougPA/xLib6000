//
//  MeterCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Meter Class extensions
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Meter {
  
  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands to the Radio (hardware)
  
  public class func subscribe(id: MeterId) {
    
    // subscribe to the specified Meter
    Api.sharedInstance.send("sub meter \(id)")
    
  }
  /// Request a list of Meters
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public class func listRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio for a list of Meters
    Api.sharedInstance.send(Api.Command.meterList.rawValue, replyTo: callback == nil ? Api.sharedInstance.radio!.defaultReplyHandler : callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // ----- NONE -----
}
