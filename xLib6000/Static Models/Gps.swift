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
  internal func parseProperties(_ properties: KeyValuesArray) {
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
        willChangeValue(forKey: "altitude")
        _altitude = property.value
        didChangeValue(forKey: "altitude")
        
      case .frequencyError:
        willChangeValue(forKey: "frequencyError")
        _frequencyError = property.value.dValue()
        didChangeValue(forKey: "frequencyError")
        
      case .grid:
        willChangeValue(forKey: "grid")
        _grid = property.value
        didChangeValue(forKey: "grid")
        
      case .latitude:
        willChangeValue(forKey: "latitude")
        _latitude = property.value
        didChangeValue(forKey: "latitude")
        
      case .longitude:
        willChangeValue(forKey: "longitude")
        _longitude = property.value
        didChangeValue(forKey: "longitude")
        
      case .speed:
        willChangeValue(forKey: "speed")
        _speed = property.value
        didChangeValue(forKey: "speed")
        
      case .status:
        willChangeValue(forKey: "status")
        _status = ( property.value == "present" ? true : false )
        didChangeValue(forKey: "status")
        
      case .time:
        willChangeValue(forKey: "time")
        _time = property.value
        didChangeValue(forKey: "time")
        
      case .track:
        willChangeValue(forKey: "track")
        _track = property.value.dValue()
        didChangeValue(forKey: "track")
        
      case .tracked:
        willChangeValue(forKey: "tracked")
        _tracked = property.value.bValue()
        didChangeValue(forKey: "tracked")
        
      case .visible:
        willChangeValue(forKey: "visible")
        _visible = property.value.bValue()
        didChangeValue(forKey: "visible")
      }
    }
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
