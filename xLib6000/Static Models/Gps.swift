//
//  Gps.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Gps Class implementation
//
//      creates a Gps instance to be used by a Client to support the
//      processing of the internal Gps (if installed). Gps objects are added,
//      removed and updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Gps                      : NSObject, PropertiesParser {

  static let kGpsCmd                        = "radio gps "

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization

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
  // MARK: - Class methods that send Commands to the Radio (hardware)
  
  /// Gps Install
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func gpsInstall(callback: ReplyHandler? = nil) {
    
    // tell the Radio to install the GPS device
    Api.sharedInstance.send(kGpsCmd + "install", replyTo: callback)
  }
  /// Gps Un-Install
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public class func gpsUnInstall(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the GPS device
    Api.sharedInstance.send(kGpsCmd + "uninstall", replyTo: callback)
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Gps
  ///
  /// - Parameters:
  ///   - radio:              parent Radio class
  ///   - queue:              Concurrent queue
  ///
  public init(queue: DispatchQueue) {
    self._q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse a Gps status message
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // Format: <"lat", value> <"lon", value> <"grid", value> <"altitude", value> <"tracked", value> <"visible", value> <"speed", value>
    //          <"freq_error", value> <"status", "Not Present" | "Present"> <"time", value> <"track", value>
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = Token(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .altitude:
        update(&_altitude, value: property.value, key: "altitude")

      case .frequencyError:
        update(&_frequencyError, value: property.value.dValue(), key: "frequencyError")

      case .grid:
        update(&_grid, value: property.value, key: "grid")

      case .latitude:
        update(&_latitude, value: property.value, key: "latitude")

      case .longitude:
        update(&_longitude, value: property.value, key: "longitude")

      case .speed:
        update(&_speed, value: property.value, key: "speed")

      case .status:
        update(&_status, value: ( property.value == "present" ? true : false ), key: "status")

      case .time:
        update(&_time, value: property.value, key: "time")

      case .track:
        update(&_track, value: property.value.dValue(), key: "track")

      case .tracked:
        update(&_tracked, value: property.value.bValue(), key: "tracked")

      case .visible:
        update(&_visible, value: property.value.bValue(), key: "visible")
      }
    }
  }
  /// Update a property & signal KVO
  ///
  /// - Parameters:
  ///   - property:           the property (mutable)
  ///   - value:              the new value
  ///   - key:                the KVO key
  ///
  private func update<T: Equatable>(_ property: inout T, value: T, key: String) {
    
    // update the property & signal KVO (if needed)
//    if property != value {
      willChangeValue(forKey: key)
      property = value
      didChangeValue(forKey: key)
//    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Gps Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Gps tokens
// --------------------------------------------------------------------------------

extension Gps {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
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
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
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
  // MARK: - Gps tokens
  
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
