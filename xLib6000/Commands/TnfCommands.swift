//
//  TnfCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Tnf Class extensions
//              - Static command prefix properties
//              - Public class methods that send Commands to the Radio (hardware)
//              - Public instance methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Tnf {
  
  static let kCreateCmd                     = "tnf create "                 // Command prefixes
  static let kRemoveCmd                     = "tnf remove "
  static let kSetCmd                        = "tnf set "
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Class methods that send Commands to the Radio (hardware)

  /// Create a Tnf
  ///
  /// - Parameters:
  ///   - frequency:          frequency (Hz)
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func create(frequency: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to create a Tnf
    Api.sharedInstance.send(Tnf.kCreateCmd + "freq" + "=\(frequency)", replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods that send Commands to the Radio (hardware)

  /// Remove a Tnf
  ///
  /// - Parameters:
  ///   - tnf:                Tnf Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Tnf
    Api.sharedInstance.send(Tnf.kRemoveCmd + " \(id)", replyTo: callback)
    
    // notify all observers
    NC.post(.tnfWillBeRemoved, object: self as Any?)
    
    // remove the Tnf
    Api.sharedInstance.radio!.tnfs[self.id] = nil
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a Tnf property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func tnfCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Tnf.kSetCmd + "\(id) " + token.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var depth: Int {
    get { return _depth }
    set { if _depth != newValue { if depth.within(Depth.normal.rawValue, Depth.veryDeep.rawValue) {
      _depth = newValue ; tnfCmd( .depth, newValue) } } } }
  
  @objc dynamic public var frequency: Int {
    get { return _frequency }
    set { if _frequency != newValue { _frequency = newValue ; tnfCmd( .frequency, newValue.hzToMhz) } } }
  
  @objc dynamic public var permanent: Bool {
    get { return _permanent }
    set { if _permanent != newValue { _permanent = newValue ; tnfCmd( .permanent, newValue.asNumber) } } }
  
  @objc dynamic public var width: Int {
    get { return _width  }
    set { if _width != newValue { if newValue.within(minWidth, maxWidth) { _width = newValue ; tnfCmd( .width, newValue.hzToMhz) } } } }
}
