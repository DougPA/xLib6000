//
//  GuiClient.swift
//  xLib6000
//
//  Created by Douglas Adams on 4/8/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Foundation
import os.log

/// GuiClient Class implementation
///
///      creates a GuiClient instance to be used by a Client to support the
///      processing of the connected Gui Clients. GuiClient objects are added, removed and
///      updated by the incoming TCP messages. They are collected in the guiClients
///      collection on the Radio object.
///
public final class GuiClient                : NSObject, DynamicModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kConnected                     = "connected"
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var handle            : UInt32                        // Session unique handle of this Gui Client

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "BandSetting")
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __id                          : UUID?                         // UUID that identifies a GUI CLient
  private var __localPtt                    = false                         // Local PTT
  private var __program                     = ""                            // Name that describes a Gui Client program
  private var __station                     = ""                            // Name that describes a Gui Client
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods
  
  /// Parse a Client status message
  ///
  ///   StatusParser Protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format:  <client_handle, > <connected, > <"client_id", clientId> <"program", program> <"station", station> <"local_ptt", 0/1>
    
    // get the Client Handle
    if let handle = keyValues[0].key.handle {
      
      // is it connected?
      if keyValues[1].key == GuiClient.kConnected {
        // YES, does the Client Handle exist?
        if radio.guiClients[handle] == nil {
          
          // NO, create a new GuiClient & add it to the guiClients collection
          radio.guiClients[handle] = GuiClient(handle: handle, queue: queue)
        }
        // pass the remaining key values to the guiClient for parsing
        radio.guiClients[handle]!.parseProperties( Array(keyValues.dropFirst(2)) )
        
      } else {
        // NO, notify all observers
        NC.post(.guiClientWillBeRemoved, object: radio.guiClients[handle] as Any?)
        
        // remove it
        radio.guiClients[handle] = nil
      }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a BandSetting
  ///
  /// - Parameters:
  ///   - handle:             a Client Handle
  ///   - isGui:              whether Client is a Gui Client
  ///   - queue:              Concurrent queue
  ///
  public init(handle: UInt32, queue: DispatchQueue) {
    
    self.handle = handle
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods
  
  /// Parse Client key/value pairs
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        // log it and ignore this Key
        os_log("Unknown GuiClient token - %{public}@ = %{public}@", log: _log, type: .default, property.key, property.value)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .id:
        willChangeValue(for: \.id)
        _id = UUID(uuidString: property.value)
        didChangeValue(for: \.id)
        
      case .localPtt:
        willChangeValue(for: \.localPtt)
        _localPtt = property.value.bValue
        didChangeValue(for: \.localPtt)

      case .program:
        willChangeValue(for: \.program)
        _program = property.value
        didChangeValue(for: \.program)
        
      case .station:
        willChangeValue(for: \.station)
        _station = property.value
        didChangeValue(for: \.station)
      }
    }
    // is the Gui Client initialized?
    if !_initialized {
      
      // YES
      _initialized = true
      
      // notify all observers
      NC.post(.guiClientHasBeenAdded, object: self as Any?)
    }

  //    guard keyValues.count >= 2 else {
  //
  //      os_log("Invalid client status", log: _log, type: .default)
  //      return
  //    }
  //
  //    // what is the message?
  //    if keyValues[1].key == "connected" {
  //
  //      let properties = keyValues.dropFirst(2)

  
//
//    } else if (keyValues[1].key == "disconnected" && keyValues[2].key == "forced") {
//      // FIXME: Handle the disconnect?
//      // Disconnected
//      os_log("Disconnect, forced = %{public}@", log: _log, type: .info, keyValues[2].value)
//
//    } else {
//      // Unrecognized
//      os_log("Unprocessed Client message, %{public}@", log: _log, type: .default, keyValues[0].key)
  }
}

extension GuiClient {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _id: UUID? {
    get { return _q.sync { __id } }
    set { _q.sync(flags: .barrier) {__id = newValue } } }
  
  internal var _localPtt: Bool {
    get { return _q.sync { __localPtt } }
    set { _q.sync(flags: .barrier) {__localPtt = newValue } } }
  
  internal var _program: String {
    get { return _q.sync { __program } }
    set { _q.sync(flags: .barrier) {__program = newValue } } }
  
  internal var _station: String {
    get { return _q.sync { __station } }
    set { _q.sync(flags: .barrier) {__station = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var id: UUID? {
    return _id }

  @objc dynamic public var localPtt: Bool {
    return _localPtt }
  
  @objc dynamic public var program: String {
    return _program }
  
  @objc dynamic public var station: String {
    return _station }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties acc_txreq_enable
  ///
  internal enum Token : String {
    case id                             = "client_id"
    case localPtt                       = "local_ptt"
    case program
    case station
  }
}
