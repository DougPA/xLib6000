//
//  GuiClient.swift
//  xLib6000
//
//  Created by Douglas Adams on 4/8/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Foundation

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
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware
  private let _log                          = Log.sharedInstance

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __host                        = ""                            // Host of a GUI CLient
  private var __id                          : UUID?                         // UUID that identifies a GUI CLient
  private var __ip                          = ""                            // Ip Address of a GUI CLient
  private var __isAvailable                 = true                          //
  private var __localPttEnabled             = false                         // Local PTT enabled
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
    let handle = keyValues[0].key.handle
    
    // is it connected?
    if keyValues[1].key == GuiClient.kConnected {
      // YES, does the Client Handle exist?
      if Api.sharedInstance.guiClients[handle] == nil {
        
        // NO, create a new GuiClient & add it to the guiClients collection
        Api.sharedInstance.guiClients[handle] = GuiClient(handle: handle, queue: queue)
      }
      // pass the remaining key values to the guiClient for parsing
      Api.sharedInstance.guiClients[handle]!.parseProperties( Array(keyValues.dropFirst(2)) )
      
    } else {
      // NO, notify all observers
      NC.post(.guiClientWillBeRemoved, object: Api.sharedInstance.guiClients[handle] as Any?)
      
      // remove it
      Api.sharedInstance.guiClients[handle] = nil
    }
  }
  /// Parse a Discovery message
  ///
  /// - Parameters:
  ///   - radio:            the Discovered radio
  ///   - api:              a reference to the Api object
  ///
  class func parseDiscoveryClients(_ radio: DiscoveredRadio, queue: DispatchQueue) {
    
    let _api = Api.sharedInstance
    
    // separate the values
    let handles   = radio.guiClientHandles.valuesArray(delimiter: ",")
    let hosts     = radio.guiClientHosts.valuesArray(delimiter: ",")
    let ips       = radio.guiClientIps.valuesArray(delimiter: ",")
    let programs  = radio.guiClientPrograms.valuesArray(delimiter: ",")
    let stations  = radio.guiClientStations.valuesArray(delimiter: ",")
    
    // are all the entries present?
    if programs.count == handles.count && stations.count == handles.count && hosts.count == handles.count && ips.count == handles.count {
      
      // YES, for each client
      for (i, handleString) in handles.enumerated() {
        
        // convert the String to a ClientHandle
        let handle = handleString.handle
        
        // does the handle exist?
        if _api.guiClients[handle] == nil {
          // NO, create a new GuiClient
          Api.sharedInstance.guiClients[handle] = GuiClient(handle: handle, queue: queue)
        
        }
        // save the values
        _api.guiClients[handle]!._host = hosts[i]
        _api.guiClients[handle]!._ip = ips[i]
        _api.guiClients[handle]!._station = stations[i]
        _api.guiClients[handle]!._program = programs[i]
        _api.guiClients[handle]!._station = stations[i]
      }
    }
  }
  
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a GuiClient
  ///
  /// - Parameters:
  ///   - handle:             a Client Handle
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
      guard let token = ClientToken(rawValue: property.key) else {
        // log it and ignore this Key
        _log.msg( "Unknown GuiClient token - \(property.key) = \(property.value)", level: .info, function: #function, file: #file, line: #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .host:
        willChangeValue(for: \.host)
        _host = property.value
        didChangeValue(for: \.host)
        
      case .id:
        willChangeValue(for: \.id)
        _id = UUID(uuidString: property.value)
        didChangeValue(for: \.id)
        
      case .ip:
        willChangeValue(for: \.ip)
        _ip = property.value
        didChangeValue(for: \.ip)
        
      case .localPttEnabled:
        willChangeValue(for: \.localPttEnabled)
        _localPttEnabled = property.value.bValue
        didChangeValue(for: \.localPttEnabled)

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
    if !_initialized && _program != "" && _station != "" {
      
      // YES
      _initialized = true
      
      // notify all observers
      NC.post(.guiClientHasBeenAdded, object: self as Any?)
    }
  }
}

extension GuiClient {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _host: String {
    get { return _q.sync { __host } }
    set { _q.sync(flags: .barrier) {__host = newValue } } }
  
  internal var _id: UUID? {
    get { return _q.sync { __id } }
    set { _q.sync(flags: .barrier) {__id = newValue } } }
  
  internal var _ip: String {
    get { return _q.sync { __ip } }
    set { _q.sync(flags: .barrier) {__ip = newValue } } }
  
  internal var _localPttEnabled: Bool {
    get { return _q.sync { __localPttEnabled } }
    set { _q.sync(flags: .barrier) {__localPttEnabled = newValue } } }
  
  internal var _program: String {
    get { return _q.sync { __program } }
    set { _q.sync(flags: .barrier) {__program = newValue } } }
  
  internal var _station: String {
    get { return _q.sync { __station } }
    set { _q.sync(flags: .barrier) {__station = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var host: String {
    return _host }
  
  @objc dynamic public var id: UUID? {
    return _id }

  @objc dynamic public var ip: String {
    return _ip }
  
  @objc dynamic public var localPttEnabled: Bool {
    return _localPttEnabled }
  
  @objc dynamic public var program: String {
    return _program }
  
  @objc dynamic public var station: String {
    return _station }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum ClientToken : String {
    case host
    case id                             = "client_id"
    case ip
    case localPttEnabled                = "local_ptt"
    case program
    case station
  }
}
