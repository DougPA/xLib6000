//
//  Meter.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation
import os

public typealias MeterId = String
public typealias MeterName = String

// --------------------------------------------------------------------------------
// MARK: - MeterStreamHandler protocol
//
// --------------------------------------------------------------------------------

protocol MeterStreamHandler                 : class {
  
  // method to process Meter data
  func streamHandler(_ value: Int16 ) -> Void
}

// ----------------------------------------------------------------------------------
// MARK: - Meter Class implementation
//
//      creates a Meter instance to be used by a Client to support the
//      rendering of a Meter. Meter objects are added / removed by the
//      incoming TCP messages. Meters are periodically updated by a UDP
//      stream containing multiple Meters.
//
// ----------------------------------------------------------------------------------

public final class Meter                    : NSObject, DynamicModel, MeterStreamHandler {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : MeterId = ""                  // Id that uniquely identifies this Meter

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "Meter")
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio (hardware)

  private var _voltsAmpsDenom               : Float = 256.0                 // denominator for voltage/amperage depends on API version

  private let kDbDbmDbfsSwrDenom            : Float = 128.0                 // denominator for Db, Dbm, Dbfs, Swr
  private let kDegDenom                     : Float = 64.0                  // denominator for Degc, Degf
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var _desc                         = ""                            // long description
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
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      VitaProcessor protocol methods
  
  //      called by Radio on the streamQ
  //
  //      The payload of the incoming Vita struct is converted to Meter values
  //      which are passed to their respective Meter Stream Handlers

  /// Process the Meter Vita struct
  ///
  /// - Parameters:
  ///   - vita:        a Vita struct
  ///
  class func vitaProcessor(_ vita: Vita) {
    var metersFound = [UInt16]()

    // NOTE:  there is a bug in the Radio (as of v2.2.8) that sends
    //        multiple copies of meters, this code ignores the duplicates
    
    let payloadPtr = UnsafeRawPointer(vita.payloadData)
    
    // four bytes per Meter
    let numberOfMeters = Int(vita.payloadSize / 4)
    
    // pointer to the first Meter number / Meter value pair
    let ptr16 = payloadPtr.bindMemory(to: UInt16.self, capacity: 2)
    
    // for each meter in the Meters packet
    for i in 0..<numberOfMeters {
      
      // get the Meter number and the Meter value
      let meterNumber: UInt16 = CFSwapInt16BigToHost(ptr16.advanced(by: 2 * i).pointee)
      let meterValue: UInt16 = CFSwapInt16BigToHost(ptr16.advanced(by: (2 * i) + 1).pointee)
      
      // is this a duplicate?
      if !metersFound.contains(meterNumber) {
        
        // NO, add it to the list
        metersFound.append(meterNumber)
        
        // find the meter (if present) & update it
        if let meter = Api.sharedInstance.radio?.meters[String(format: "%i", meterNumber)] {
          
          // interpret it as a signed value
          meter.streamHandler( Int16(bitPattern: meterValue) )
        }
      }
//      else {
//
//        // duplicate meter in packet, log it and ignore it
//        Log.sharedInstance.msg("Duplicate meter in packet, number = \(meterNumber)", level: .warning, function: #function, file: #file, line: #line)
//      }
    }
  }
  /// Find Meters by a Slice Id
  ///
  /// - Parameters:
  ///   - sliceId:    a Slice id
  /// - Returns:      an array of Meters
  ///
  public class func findBy(sliceId: SliceId) -> [Meter] {
    
    // find the Meters on the specified Slice (if any)
    return Api.sharedInstance.radio!.meters.values.filter { $0.source == "slc" && $0.number == sliceId }
  }
  /// Find a Meter by its ShortName
  ///
  /// - Parameters:
  ///   - name:       Short Name of a Meter
  /// - Returns:      a Meter reference
  ///
  public class func findBy(shortName name: MeterName) -> Meter? {

    // find the Meters with the specified Name (if any)
    let meters = Api.sharedInstance.radio!.meters.values.filter { $0.name == name }
    guard meters.count >= 1 else { return nil }
    
    // return the first one
    return meters[0]
  }

  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
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
      
      // IN USE, extract the Meter Number from the first KeyValues entry
      let components = keyValues[0].key.components(separatedBy: ".")
      if components.count != 2 {return }

      // the Meter Id is the 0th item (MeterNumber)
      let meterId = components[0]
      
      // does the meter exist?
      if radio.meters[meterId] == nil {
        
        // DOES NOT EXIST, create a new Meter & add it to the Meters collection
        radio.meters[meterId] = Meter(id: meterId, queue: queue)
      }
      
      // pass the key values to the Meter for parsing
      radio.meters[meterId]!.parseProperties( keyValues )

    } else {
      
      // NOT IN USE, extract the Meter Number
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

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Meter
  ///
  /// - Parameters:
  ///   - id:                 a Meter Id
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
        os_log("Unknown Meter token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      
      // known Keys, in alphabetical order
      switch token {
        
      case .desc:
        desc = property.value
        
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
    if !_initialized && number != "" && units != "" {
      
      // the Radio (hardware) has acknowledged this Meter
      _initialized = true
      
      // is it a Slice meter?
      if source == Meter.Source.slice.rawValue {
        
        // YES, does the Slice exist (yet)
        if let slice = _api.radio!.slices[number] {
          
          // YES, add it to the Slice
          slice.addMeter(self)
          
          // notify all observers
          NC.post(.sliceMeterHasBeenAdded, object: self as Any?)
        }

      } else {
        
        // notify all observers
        NC.post(.meterHasBeenAdded, object: self as Any?)
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - MeterStreamHandler protocol methods
  
  /// Process the UDP Stream Data for the Meter (arrives on the streamQ)
  ///
  /// - Parameters:
  ///   - newValue:   the new value for the Meter
  ///
  func streamHandler(_ newValue: Int16) {
    let previousValue = value
    
    // check for unknown Units
    guard let token = Units(rawValue: units) else {
      
      // unknown Units, log it and ignore it
      os_log("Meter, Unknown units - %{public}@", log: _log, type: .default, units)
      
      return
    }
    var adjNewValue: Float = 0.0
    switch token {
      
    case .db, .dbm, .dbfs, .swr:
      adjNewValue = Float(newValue) / kDbDbmDbfsSwrDenom
      
    case .volts, .amps:
      adjNewValue = Float(newValue) / _voltsAmpsDenom
      
    case .degc, .degf:
      adjNewValue = Float(newValue) / kDegDenom
    
    case .rpm, .watts, .percent, .none:
      adjNewValue = Float(newValue)
    }
    // did it change?
    if adjNewValue != previousValue {
      // notify all observers
      NC.post(.meterUpdated, object: self as Any?)
      
      value = adjNewValue
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
  @objc dynamic public var desc: String {
    get { return _q.sync { _desc } }
    set { _q.sync(flags: .barrier) { _desc = newValue } } }
  
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
    case none
    case amps
    case db
    case dbfs
    case dbm
    case degc
    case degf
    case percent
    case rpm
    case swr
    case volts
    case watts
  }
  
}
