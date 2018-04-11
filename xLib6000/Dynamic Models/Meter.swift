//
//  Meter.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

public typealias MeterId = String
public typealias MeterName = String

// ----------------------------------------------------------------------------------
// MARK: - Meter Class implementation
//
//      creates a Meter instance to be used by a Client to support the
//      rendering of a Meter. Meter objects are added / removed by the
//      incoming TCP messages. Meters are periodically updated by a UDP
//      stream containing multiple Meters.
//
// ----------------------------------------------------------------------------------

public final class Meter                    : StatusParser, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : MeterId = ""                  // Id that uniquely identifies this Meter

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio (hardware)

  private var _voltsAmpsDenom               : Float = 256.0                 // denominator for voltage/amperage depends on API version

  private let kSwrDbmDbfsDenom              : Float = 128.0                 // denominator for Swr, Dbm, Dbfs
  private let kDegcDenom                    : Float = 64.0                  // denominator for Degc
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var _description                  = ""                            // long description
  private var _fps                          = 0                             // frames per second
  private var _high: Float                  = 0.0                           // high limit
  private var _low: Float                   = 0.0                           // low limit
  private var _number                       = ""                            // Id of the source
  private var _name                         = ""                            // abbreviated description
  private var _peak                         : Float = 0.0                   // peak value
  private var _source                       = ""                            // source
  private var _units                        = ""                            // value units
  private var _value                        : Float = 0.0                   // value
  //                                                                                              
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ----------------------------------------------------------------------------
  // MARK: - Class methods
  
  /// Process the Panadapter Vita struct
  ///
  /// - Parameters:
  ///   - vita:        a Vita struct
  ///
  class func vitaProcessor(_ vita: Vita) {
    
    // four bytes per Meter
    let numberOfMeters = Int(vita.payloadSize / 4)
    
    // pointer to the first Meter number / Meter value pair
    if let ptr16 = (vita.payload)?.bindMemory(to: UInt16.self, capacity: 2) {
      
      // for each meter in the Meters packet
      for i in 0..<numberOfMeters {
        
        // get the Meter number and the Meter value
        let meterNumber: UInt16 = CFSwapInt16BigToHost(ptr16.advanced(by: 2 * i).pointee)
        let meterValue: UInt16 = CFSwapInt16BigToHost(ptr16.advanced(by: (2 * i) + 1).pointee)
        
        // Find the meter (if present) & update it
        if let meter = Api.sharedInstance.radio?.meters[String(format: "%i", meterNumber)] {
          
          // interpret it as a signed value
          meter.update( Int16(bitPattern: meterValue) )
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Meter
  ///
  /// - Parameters:
  ///   - id:                 a Meter Id
  ///   - radio:              the parent Radio class
  ///   - queue:              Concurrent queue
  ///
  public init(id: MeterId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    // FIXME:
    
    // set voltage/amperage denominator for older API versions (before 1.11)
    if Api.sharedInstance.apiVersionMajor == 1 && Api.sharedInstance.apiVersionMinor <= 10 {
      _voltsAmpsDenom = 1024.0
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Update meter readings, called by UdpManager, executes on the udpReceiveQ
  ///
  /// - Parameters:
  ///   - newValue:   the new value for the Meter
  ///
  func update(_ newValue: Int16) {
    let oldValue = value
    
    // check for unknown Units
    guard let token = Units(rawValue: units) else {
      
      // unknown Units, log it and ignore it
      Log.sharedInstance.msg("Meter \(id).\(description), Unknown units - \(units)", level: .debug, function: #function, file: #file, line: #line)
      return
    }
    
    switch token {
      
    case .volts, .amps:
      value = Float(newValue) / _voltsAmpsDenom
      
    case .swr, .dbm, .dbfs:
      value = Float(newValue) / kSwrDbmDbfsDenom
      
    case .degc:
      value = Float(newValue) / kDegcDenom
    }
    // did it change?
    if oldValue != value {
      // notify all observers
      NC.post(.meterUpdated, object: self as Any?)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - StatusParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse a Meter status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format: <number."src", src> <number."nam", name> <number."hi", highValue> <number."desc", description> <number."unit", unit> ,number."fps", fps>
    //      OR
    // Format: <number "removed", "">
    
    // is the Meter in use?
    if inUse {
      
      // YES, extract the Meter Number from the first KeyValues entry
      let components = keyValues[0].key.components(separatedBy: ".")
      if components.count != 2 {return }
      
      // the Meter Id is the 0th item (MeterNumber)
      let meterId = components[0]
      
      // does the meter exist?
      if radio.meters[meterId] == nil {
        
        // NO, create a new Meter & add it to the Meters collection
        radio.meters[meterId] = Meter(id: meterId, queue: queue)
        
        // is it a Slice meter?
        if radio.meters[meterId]!.source == Meter.Source.slice.rawValue {
          
          // YES, get the Slice
          if let slice = radio.slices[radio.meters[meterId]!.number] {
            
            // add it to the Slice
            slice.addMeter(radio.meters[meterId]!)
          }
        }
      }
      // pass the key values to the Meter for parsing
      radio.meters[meterId]!.parseProperties( keyValues )
      
    } else {
      
      // NO, extract the Meter Number
      let meterId = keyValues[0].key.components(separatedBy: " ")[0]
      
      // does it exist?
      if let meter = radio.meters[meterId] {
        
        // is it a Slice meter?
        if meter.source == Meter.Source.slice.rawValue {
          
          // YES, get the Slice
          if let slice = radio.slices[meter.number] {
            
            // remove it from the Slice
            slice.removeMeter(meterId)
          }
        }
        // notify all observers
        NC.post(.meterWillBeRemoved, object: radio.meters[meterId] as Any?)
        
        // remove it
        radio.meters[meterId] = nil
      }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse Meter key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <n.key=value>
    for property in properties {
      
      // separate the Meter Number from the Key
      let numberAndKey = property.key.components(separatedBy: ".")
      
      // get the Key
      let key = numberAndKey[1]
      
      // set the Meter Number
      id = numberAndKey[0]
      
      // check for unknown Keys
      guard let token = Token(rawValue: key) else {
        
        // unknown Key, log it and ignore the Key
        Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
        continue
      }
      
      // known Keys, in alphabetical order
      switch token {
        
      case .desc:
        description = property.value
        
      case .fps:
        fps = property.value.iValue()
        
      case .high:
        high = property.value.fValue()
        
      case .low:
        low = property.value.fValue()
        
      case .name:
        name = property.value.lowercased()
        
      case .number:
        number = property.value
        
      case .source:
        source = property.value.lowercased()
        
      case .units:
        units = property.value.lowercased()
      }
    }
    if !_initialized {
      
      // the Radio (hardware) has acknowledged this Meter
      _initialized = true
      
      // notify all observers
      NC.post(.meterHasBeenAdded, object: self as Any?)
    }
  }
  
}

// --------------------------------------------------------------------------------
// MARK: - Meter Class extensions
//              - Public properties, no message to Radio
//              - Meter tokens
//              - Meter related enums
// --------------------------------------------------------------------------------

extension Meter {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var description: String {
    get { return _q.sync { _description } }
    set { _q.sync(flags: .barrier) { _description = newValue } } }
  
  @objc dynamic public var fps: Int {
    get { return _q.sync { _fps } }
    set { _q.sync(flags: .barrier) { _fps = newValue } } }
  
  @objc dynamic public var high: Float {
    get { return _q.sync { _high } }
    set { _q.sync(flags: .barrier) { _high = newValue } } }
  
  @objc dynamic public var low: Float {
    get { return _q.sync { _low } }
    set { _q.sync(flags: .barrier) { _low = newValue } } }
  
  @objc dynamic public var name: String {
    get { return _q.sync { _name } }
    set { _q.sync(flags: .barrier) { _name = newValue } } }
  
  @objc dynamic public var number: String {
    get { return _q.sync { _number } }
    set { _q.sync(flags: .barrier) { _number = newValue } } }
  
  @objc dynamic public var peak: Float {
    get { return _q.sync { _peak } }
    set { _q.sync(flags: .barrier) { _peak = newValue } } }
  
  @objc dynamic public var source: String {
    get { return _q.sync { _source } }
    set { _q.sync(flags: .barrier) { _source = newValue } } }
  
  @objc dynamic public var units: String {
    get { return _q.sync { _units } }
    set { _q.sync(flags: .barrier) { _units = newValue } } }
  
  @objc dynamic public var value: Float {
    get { return _q.sync { _value } }
    set { _q.sync(flags: .barrier) { _value = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Meter tokens
  
  internal enum Token : String {
    case desc
    case fps
    case high       = "hi"
    case low
    case name       = "nam"
    case number     = "num"
    case source     = "src"
    case units      = "unit"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Meter related enums
  
  public enum Source: String {
    case codec      = "cod"
    case tx
    case slice      = "slc"
    case radio      = "rad"
  }
  
  public enum Units : String {
    case dbm
    case dbfs
    case swr
    case volts
    case amps
    case degc
  }
  
}
