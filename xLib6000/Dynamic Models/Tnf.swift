//
//  Tnf.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/30/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

public typealias TnfId = String

// ------------------------------------------------------------------------------
// MARK: - TNF Class implementation
//
//      creates a Tnf instance to be used by a Client to support the
//      rendering of a Tnf. Tnf objects are added, removed and
//      updated by the incoming TCP messages.
//
// ------------------------------------------------------------------------------

public final class Tnf                      : NSObject, StatusParser, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : TnfId                         // Id that uniquely identifies this Tnf

  public var minWidth                       = 5                             // default minimum Tnf width (Hz)
  public var maxWidth                       = 6000                          // default maximum Tnf width (Hz)

  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
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
    
    // does the TNF exist?
    if radio.tnfs[tnfId] == nil {
      
      // NO, create a new Tnf & add it to the Tnfs collection
      radio.tnfs[tnfId] = Tnf(id: tnfId, queue: queue)
    }
    // pass the remaining key values to the Tnf for parsing (dropping the Id)
    radio.tnfs[tnfId]!.parseProperties( Array(keyValues.dropFirst(1)) )
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Tnf
  ///
  /// - Parameters:
  ///   - id:                 a Tnf Id
  ///   - radio:              parent Radio class
  ///   - queue:              Concurrent queue
  ///
  public convenience init(id: TnfId, queue: DispatchQueue) {
    self.init(id: id, frequency: 0, depth: Tnf.Depth.normal.rawValue, width: 0, permanent: false, queue: queue)
  }
  /// Initialize a Tnf
  ///
  /// - Parameters:
  ///   - id:                 a Tnf Id
  ///   - radio:              parent Radio class
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
  ///   - radio:              parent Radio class
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
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .depth:
        update(&_depth, value: Int(property.value) ?? 1, key: "depth")

      case .frequency:
        update(&_frequency, value: property.value.mhzToHz(), key: "frequency")

      case .permanent:
        update(&_permanent, value: property.value.bValue(), key: "permanent")

      case .width:
         update(&_width, value: property.value.mhzToHz(), key: "width")
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
  /// Update a property & signal KVO
  ///
  /// - Parameters:
  ///   - property:           the property (mutable)
  ///   - value:              the new value
  ///   - key:                the KVO key
  ///
  private func update<T: Equatable>(_ property: inout T, value: T, key: String) {
    
    // update the property & signal KVO (if needed)
    if property != value {
      willChangeValue(forKey: key)
      property = value
      didChangeValue(forKey: key)
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

