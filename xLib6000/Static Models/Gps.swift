//
//  Gps.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Gps Class implementation
///
///      creates a Gps instance to be used by a Client to support the
///      processing of the internal Gps (if installed). Gps objects are added,
///      removed and updated by the incoming TCP messages.
///
public final class Gps                      : NSObject, StaticModel {

  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kGpsCmd                        = "radio gps "

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue                 // Q for object synchronization

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //                                                                                              
  private var __altitude                    = ""                            //
  private var __frequencyError              = 0.0                           //
  private var __grid                        = ""                            //
  private var __latitude                    = ""                            //
  private var __longitude                   = ""                            //
  private var __speed                       = ""                            //
  private var __status                      = false                         //
  private var __time                        = ""                            //
  private var __track                       = 0.0                           //
  private var __tracked                     = false                         //
  private var __visible                     = false                         //
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands
  
  /// Gps Install
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func gpsInstall(callback: ReplyHandler? = nil) {
    
    // tell the Radio to install the GPS device
    Api.sharedInstance.send("radio gps install", replyTo: callback)
  }
  /// Gps Un-Install
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func gpsUnInstall(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the GPS device
    Api.sharedInstance.send("radio gps uninstall", replyTo: callback)
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Gps
  ///
  /// - Parameters:
  ///   - queue:              Concurrent queue
  ///
  public init(queue: DispatchQueue) {
    self._q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods

  /// Parse a Gps status message
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // Format: <"lat", value> <"lon", value> <"grid", value> <"altitude", value> <"tracked", value> <"visible", value> <"speed", value>
    //          <"freq_error", value> <"status", "Not Present" | "Present"> <"time", value> <"track", value>
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown Keys
      guard let token = Token(rawValue: property.key)  else {
        // log it and ignore the Key
        _log.msg("Unknown Gps token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .altitude:
        willChangeValue(for: \.altitude)
        _altitude = property.value
        didChangeValue(for: \.altitude)

      case .frequencyError:
        willChangeValue(for: \.frequencyError)
        _frequencyError = property.value.dValue
        didChangeValue(for: \.frequencyError)

      case .grid:
        willChangeValue(for: \.grid)
        _grid = property.value
        didChangeValue(for: \.grid)

      case .latitude:
        willChangeValue(for: \.latitude)
        _latitude = property.value
        didChangeValue(for: \.latitude)

      case .longitude:
        willChangeValue(for: \.longitude)
        _longitude = property.value
        didChangeValue(for: \.longitude)

      case .speed:
        willChangeValue(for: \.speed)
        _speed = property.value
        didChangeValue(for: \.speed)

      case .status:
        willChangeValue(for: \.status)
        _status = ( property.value == "present" ? true : false )
        didChangeValue(for: \.status)

      case .time:
        willChangeValue(for: \.time)
        _time = property.value
        didChangeValue(for: \.time)

      case .track:
        willChangeValue(for: \.track)
        _track = property.value.dValue
        didChangeValue(for: \.track)

      case .tracked:
        willChangeValue(for: \.tracked)
        _tracked = property.value.bValue
        didChangeValue(for: \.tracked)

      case .visible:
        willChangeValue(for: \.visible)
        _visible = property.value.bValue
        didChangeValue(for: \.visible)
      }
    }
  }
}

extension Gps {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _altitude: String {
    get { return _q.sync { __altitude } }
    set { _q.sync(flags: .barrier) { __altitude = newValue } } }
  
  internal var _frequencyError: Double {
    get { return _q.sync { __frequencyError } }
    set { _q.sync(flags: .barrier) { __frequencyError = newValue } } }
  
  internal var _grid: String {
    get { return _q.sync { __grid } }
    set { _q.sync(flags: .barrier) { __grid = newValue } } }
  
  internal var _latitude: String {
    get { return _q.sync { __latitude } }
    set { _q.sync(flags: .barrier) { __latitude = newValue } } }
  
  internal var _longitude: String {
    get { return _q.sync { __longitude } }
    set { _q.sync(flags: .barrier) { __longitude = newValue } } }
  
  internal var _speed: String {
    get { return _q.sync { __speed } }
    set { _q.sync(flags: .barrier) { __speed = newValue } } }
  
  internal var _status: Bool {
    get { return _q.sync { __status } }
    set { _q.sync(flags: .barrier) { __status = newValue } } }
  
  internal var _time: String {
    get { return _q.sync { __time } }
    set { _q.sync(flags: .barrier) { __time = newValue } } }
  
  internal var _track: Double {
    get { return _q.sync { __track } }
    set { _q.sync(flags: .barrier) { __track = newValue } } }
  
  internal var _tracked: Bool {
    get { return _q.sync { __tracked } }
    set { _q.sync(flags: .barrier) { __tracked = newValue } } }
  
  internal var _visible: Bool {
    get { return _q.sync { __visible } }
    set { _q.sync(flags: .barrier) { __visible = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var altitude: String {
    return _altitude }
  
  @objc dynamic public var frequencyError: Double {
    return _frequencyError }
  
  @objc dynamic public var grid: String {
    return _grid }
  
  @objc dynamic public var latitude: String {
    return _latitude }
  
  @objc dynamic public var longitude: String {
    return _longitude }
  
  @objc dynamic public var speed: String {
    return _speed }
  
  @objc dynamic public var status: Bool {
    return _status }
  
  @objc dynamic public var time: String {
    return _time }
  
  @objc dynamic public var track: Double {
    return _track }
  
  @objc dynamic public var tracked: Bool {
    return _tracked }
  
  @objc dynamic public var visible: Bool {
    return _visible }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
internal enum Token: String {
    case altitude
    case frequencyError = "freq_error"
    case grid
    case latitude = "lat"
    case longitude = "lon"
    case speed
    case status
    case time
    case track
    case tracked
    case visible
  }
  
}
