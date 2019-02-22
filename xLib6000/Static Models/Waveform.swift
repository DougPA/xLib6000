//
//  Waveform.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import os

/// Waveform Class implementation
///
///      creates a Waveform instance to be used by a Client to support the
///      processing of installed Waveform functions. Waveform objects are added,
///      removed and updated by the incoming TCP messages.
///
public final class Waveform                 : NSObject, StaticModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = OSLog(subsystem: Api.kBundleIdentifier, category: "Waveform")
  private let _q                            : DispatchQueue                 // Q for object synchronization

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __waveformList                = ""                            //
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Waveform
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

  /// Parse a Waveform status message
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = Token(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        os_log("Unknown Waveform token = %{public}@", log: _log, type: .default, property.key)
        
        continue
      }      
      // Known tokens, in alphabetical order
      switch token {
        
      case .waveformList:
        willChangeValue(for: \.waveformList)
        _waveformList = property.value
        didChangeValue(for: \.waveformList)

      }
    }
  }
}

extension Waveform {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _waveformList: String {
    get { return _q.sync { __waveformList } }
    set { _q.sync(flags: .barrier) { __waveformList = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var waveformList: String {
    return _waveformList }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum Token: String {
    case waveformList = "installed_list"
  }
}
