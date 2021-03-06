//
//  AmplifierCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation


// --------------------------------------------------------------------------------
// MARK: - Amplifier Class extensions
//              - Static command prefix properties
//              - Public class methods that send Commands to the Radio (hardware)
//              - Public instance methods that send Commands to the Radio (hardware)
//              - Dynamic public properties that send commands to the Radio
// --------------------------------------------------------------------------------

extension Amplifier {
  
  static let kSetCmd                        = "amplifier set "              // Command prefixes
  static let kOperate                       = "OPERATE"
  static let kStandby                       = "STANDBY"
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Class methods that send Commands to the Radio (hardware)

  /// Create an Amplifier record
  ///
  /// - Parameters:
  ///   - ip:             Ip Address (dotted-decimal STring)
  ///   - port:           Port number
  ///   - model:          Model
  ///   - serialNumber:   Serial number
  ///   - antennaPairs:   antenna pairs
  ///   - callback:       ReplyHandler (optional)
  ///
  public class func create(ip: String, port: Int, model: String, serialNumber: String, antennaPairs: String, callback: ReplyHandler? = nil) {
    
    // TODO: add code
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods that send Commands to the Radio (hardware)

  /// Remove this Amplifier record
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil) {
    
    // TODO: add code
  }
  /// Change the Amplifier Mode
  ///
  /// - Parameters:
  ///   - mode:           mode (String)
  ///   - callback:       ReplyHandler (optional)
  ///
  public func setMode(_ mode: Bool, callback: ReplyHandler? = nil) {
    
    // TODO: add code
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set an Amplifier property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func amplifierCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Amplifier.kSetCmd + "\(id) " + token.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (with message sent to Radio)
  
  // listed in alphabetical order
  @objc dynamic public var ant: String {
    get { return _ant }
    set { if _ant != newValue { _ant = newValue ; amplifierCmd(.ant, newValue) } } }
  
  @objc dynamic public var ip: String {
    get { return _ip }
    set { if _ip != newValue { _ip = newValue ; amplifierCmd(.ip, newValue) } } }
  
  @objc dynamic public var model: String {
    get { return _model }
    set { if _model != newValue { _model = newValue ; amplifierCmd(.model, newValue) } } }
  
  @objc dynamic public var mode: String {
    get { return _mode }
    set { if _mode != newValue { _mode = newValue ; amplifierCmd(.mode, newValue) } } }
  
  @objc dynamic public var port: Int {
    get { return _port }
    set { if _port != newValue { _port = newValue ; amplifierCmd( .port, newValue) } } }
  
  @objc dynamic public var serialNumber: String {
    get { return _serialNumber }
    set { if _serialNumber != newValue { _serialNumber = newValue ; amplifierCmd( .serialNumber, newValue) } } }
}
