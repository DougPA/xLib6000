//
//  Tnf.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/30/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation
import os

public typealias TnfId = String

// ------------------------------------------------------------------------------
// MARK: - TNF Class implementation
//
//      creates a Tnf instance to be used by a Client to support the
//      rendering of a Tnf. Tnf objects are added, removed and
//      updated by the incoming TCP messages.
//
// ------------------------------------------------------------------------------

public final class Tnf                      : NSObject, DynamicModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : TnfId                         // Id that uniquely identifies this Tnf

  public var minWidth                       = 5                             // default minimum Tnf width (Hz)
  public var maxWidth                       = 6000                          // default maximum Tnf width (Hz)

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "Tnf")
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //                                                                                                  
  private var __depth                       = Tnf.Depth.normal.rawValue     // Depth (Normal, Deep, Very Deep)
  private var __frequency                   = 0                             // Frequency (Hz)
  private var __permanent                   = false                         // True =
  private var __width                       = 0                             // Width (Hz)
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a Tnf status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    
    // get the Tnf Id
    let tnfId = keyValues[0].key
    
    // is the Tnf in use?
    if inUse {
      
      // does the TNF exist?
      if radio.tnfs[tnfId] == nil {
        
        // NO, create a new Tnf & add it to the Tnfs collection
        radio.tnfs[tnfId] = Tnf(id: tnfId, queue: queue)
      }
      // pass the remaining key values to the Tnf for parsing (dropping the Id)
      radio.tnfs[tnfId]!.parseProperties( Array(keyValues.dropFirst(1)) )

    } else {
      
      // NO, notify all observers
      NC.post(.tnfWillBeRemoved, object: Api.sharedInstance.radio!.tnfs[tnfId] as Any?)
      
      // remove it
      Api.sharedInstance.radio!.tnfs[tnfId]  = nil
    }
  }
  /// Given a Frequency, return a reference to the Tnf containing it (if any)
  ///
  /// - Parameters:
  ///   - freq:       a Frequency (in hz)
  ///   - bandwidth:  panadapter bandwidth (hz)
  /// - Returns:      a Tnf reference (or nil)
  ///
  class public func findBy(frequency freq: Int, minWidth: Int) -> Tnf? {

    // return the Tnfs within the specified Frequency / minimum width (if any)
    let tnfs = Api.sharedInstance.radio!.tnfs.values.filter { freq >= ($0.frequency - max(minWidth, $0.width/2)) && freq <= ($0.frequency + max(minWidth, $0.width/2)) }
    guard tnfs.count >= 1 else { return nil }
    
    // return the first one
    return tnfs[0]
  }
  /// Determine a frequency for a Tnf
  ///
  /// - Parameters:
  ///   - frequency:      tnf frequency (may be 0)
  ///   - panadapter:     a Panadapter reference
  /// - Returns:          the calculated Tnf frequency
  ///
  class func calcFreq(_ frequency: Int, _ panadapter: Panadapter) -> Int {
    var freqDiff = 1_000_000_000
    var targetSlice: xLib6000.Slice?
    var tnfFreq = frequency
    
    // if frequency is 0, calculate a frequency
    if tnfFreq == 0 {
      
      // for each Slice on this Panadapter find the one within freqDiff and closesst to the center
      for slice in Slice.findAll(with: panadapter.id) {
        
        // how far is it from the center?
        let diff = abs(slice.frequency - panadapter.center)
        
        // if within freqDiff of center
        if diff < freqDiff {
          
          // update the freqDiff
          freqDiff = diff
          // save the slice
          targetSlice = slice
        }
      }
      // do we have a Slice?
      if let slice = targetSlice {
        
        // YES, what mode?
        switch slice.mode {
          
        case "LSB", "DIGL":
          tnfFreq = slice.frequency + (( slice.filterLow - slice.filterHigh) / 2)
          
        case "RTTY":
          tnfFreq = slice.frequency - (slice.rttyShift / 2)
          
        case "CW", "AM", "SAM":
          tnfFreq = slice.frequency + ( slice.filterHigh / 2)
          
        case "USB", "DIGU", "FDV":
          tnfFreq = slice.frequency + (( slice.filterLow - slice.filterHigh) / 2)
          
        default:
          tnfFreq = slice.frequency + (( slice.filterHigh - slice.filterLow) / 2)
        }
        
      } else {
        
        // NO, put it in the panadapter center
        tnfFreq = panadapter.center
      }
    }
    return tnfFreq
  }
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Tnf
  ///
  /// - Parameters:
  ///   - id:                 a Tnf Id
  ///   - queue:              Concurrent queue
  ///
  public convenience init(id: TnfId, queue: DispatchQueue) {
    self.init(id: id, frequency: 0, depth: Tnf.Depth.normal.rawValue, width: 0, permanent: false, queue: queue)
  }
  /// Initialize a Tnf
  ///
  /// - Parameters:
  ///   - id:                 a Tnf Id
  ///   - frequency:          Tnf frequency (Hz)
  ///   - queue:              Concurrent queue
  ///
  public convenience init(id: TnfId, frequency: Int, queue: DispatchQueue) {
    self.init(id: id, frequency: frequency, depth: Tnf.Depth.normal.rawValue, width: 0, permanent: false, queue: queue)
  }
  /// Initialize a Tnf
  ///
  /// - Parameters:
  ///   - id:                 a Tnf Id
  ///   - frequency:          Tnf frequency (Hz)
  ///   - depth:              a Depth value
  ///   - width:              a Width value
  ///   - permanent:          true = permanent
  ///   - queue:              Concurrent queue
  ///
  public init(id: TnfId, frequency: Int, depth: Int, width: Int, permanent: Bool, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
    
    self.frequency = frequency
    self.depth = depth
    self.width = width
    self.permanent = permanent
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse Tnf key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown keys
      guard let token = Token(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
//        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .warning, function: #function, file: #file, line: #line)

        os_log("Unknown token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .depth:
        willChangeValue(for: \.depth)
        _depth = property.value.iValue()
        didChangeValue(for: \.depth)

      case .frequency:
        willChangeValue(for: \.frequency)
        _frequency = property.value.mhzToHz()
        didChangeValue(for: \.frequency)

      case .permanent:
        willChangeValue(for: \.permanent)
        _permanent = property.value.bValue()
        didChangeValue(for: \.permanent)

      case .width:
         willChangeValue(for: \.width)
         _width = property.value.mhzToHz()
         didChangeValue(for: \.width)
      }
    }
    // is the Tnf initialized?
    if !_initialized && _frequency != 0 {
      
      // YES, the Radio (hardware) has acknowledged this Tnf
      _initialized = true
      
      // notify all observers
      NC.post(.tnfHasBeenAdded, object: self as Any?)
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Tnf Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Tnf tokens
// --------------------------------------------------------------------------------

extension Tnf {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _depth: Int {
    get { return _q.sync { __depth } }
    set { _q.sync(flags: .barrier) { __depth = newValue } } }
  
  internal var _frequency: Int {
    get { return _q.sync { __frequency } }
    set { _q.sync(flags: .barrier) { __frequency = newValue } } }
  
  internal var _permanent: Bool {
    get { return _q.sync { __permanent } }
    set { _q.sync(flags: .barrier) { __permanent = newValue } } }
  
  internal var _width: Int {
    get { return _q.sync { __width } }
    set { _q.sync(flags: .barrier) { __width = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // ----- None -----
  
  // ----------------------------------------------------------------------------
  // MARK: - Tnf tokens
  
  internal enum Token : String {
    case depth
    case frequency      = "freq"
    case permanent
    case width
  }
  
  public enum Depth : Int {
    case normal         = 1
    case deep           = 2
    case veryDeep       = 3
  }
  
}

