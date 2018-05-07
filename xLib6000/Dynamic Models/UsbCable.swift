//
//  UsbCable.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/25/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

public typealias UsbCableId = String

// --------------------------------------------------------------------------------
// MARK: - USB Cable Class implementation
//
//      creates a USB Cable instance to be used by a Client to support the
//      processing of USB connections to the Radio (hardware). USB Cable objects
//      are added, removed and updated by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class UsbCable                 : NSObject, StatusParser, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : UsbCableId = ""               // Id that uniquely identifies this UsbCable

  public private(set) var cableType         : UsbCableType                  // Type of this UsbCable

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __autoReport                  = false                         //
  private var __band                        = ""                            //
  private var __dataBits                    = 0                             //
  private var __enable                      = false                         //
  private var __flowControl                 = ""                            //
  private var __name                        = ""                            //
  private var __parity                      = ""                            //
  private var __pluggedIn                   = false                         //
  private var __polarity                    = ""                            //
  private var __preamp                      = ""                            //
  private var __source                      = ""                            //
  private var __sourceRxAnt                 = ""                            //
  private var __sourceSlice                 = 0                             //
  private var __sourceTxAnt                 = ""                            //
  private var __speed                       = 0                             //
  private var __stopBits                    = 0                             //
  private var __usbLog                      = false                         //
  private var __usbLogLine                  = ""                            //
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a USB Cable status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // TYPE: CAT
    //      <id, > <type, > <enable, > <pluggedIn, > <name, > <source, > <sourceTxAnt, > <sourceRxAnt, > <sourceSLice, >
    //      <autoReport, > <preamp, > <polarity, > <log, > <speed, > <dataBits, > <stopBits, > <parity, > <flowControl, >
    //
    
    // FIXME: Need other formats
    
    // get the UsbCable Id
    let usbCableId = keyValues[0].key
    
    // does the UsbCable exist?
    if radio.usbCables[usbCableId] == nil {
      
      // NO, is it a valid cable type?
      if let cableType = UsbCable.UsbCableType(rawValue: keyValues[1].value) {
        
        // YES, create a new UsbCable & add it to the UsbCables collection
        radio.usbCables[usbCableId] = UsbCable(id: usbCableId, queue: queue, cableType: cableType)
        
      } else {
        
        // NO, log the error and ignore it
        Log.sharedInstance.msg("Invalid UsbCable Type, \(keyValues[1].value)", level: .error, function: #function, file: #file, line: #line)
        return
      }
    }
    // pass the remaining key values to the Usb Cable for parsing (dropping the Id)
    radio.usbCables[usbCableId]!.parseProperties( Array(keyValues.dropFirst(1)) )
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a UsbCable
  ///
  /// - Parameters:
  ///   - id:                 a UsbCable serial number
  ///   - radio:              parent Radio class
  ///   - queue:              Concurrent queue
  ///   - cableType:          the type of UsbCable
  ///
  public init(id: UsbCableId, queue: DispatchQueue, cableType: UsbCableType) {
    
    self.id = id
    self._q = queue
    self.cableType = cableType
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ

  /// Parse USB Cable key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // TYPE: CAT
    //      <type, > <enable, > <pluggedIn, > <name, > <source, > <sourceTxAnt, > <sourceRxAnt, > <sourceSLice, > <autoReport, >
    //      <preamp, > <polarity, > <log, > <speed, > <dataBits, > <stopBits, > <parity, > <flowControl, >
    //
    // SA3923BB8|usb_cable A5052JU7 type=cat enable=1 plugged_in=1 name=THPCATCable source=tx_ant source_tx_ant=ANT1 source_rx_ant=ANT1 source_slice=0 auto_report=1 preamp=0 polarity=active_low band=0 log=0 speed=9600 data_bits=8 stop_bits=1 parity=none flow_control=none
    
    
    // FIXME: Need other formats
    
    
    // is the Status for a cable of this type?
    if cableType.rawValue == properties[0].value {
      
      // YES,
      // process each key/value pair, <key=value>
      for property in properties {
        
        // check for unknown keys
        guard let token = Token(rawValue: property.key) else {
          
          // unknown Key, log it and ignore the Key
          Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
          continue
        }
        // Known keys, in alphabetical order
        switch token {
          
        case .autoReport:
          update(&_autoReport, value: property.value.bValue(), key: "autoReport")

        case .band:
          update(&_band, value: property.value, key: "band")

        case .cableType:
          // ignore this token's value (set by init)
          break
          
        case .dataBits:
          update(&_dataBits, value: property.value.iValue(), key: "dataBits")

        case .enable:
          update(&_enable, value: property.value.bValue(), key: "enable")

        case .flowControl:
          update(&_flowControl, value: property.value, key: "flowControl")

        case .name:
          update(&_name, value: property.value, key: "name")

        case .parity:
          update(&_parity, value: property.value, key: "parity")

        case .pluggedIn:
          update(&_pluggedIn, value: property.value.bValue(), key: "pluggedIn")

        case .polarity:
          update(&_polarity, value: property.value, key: "polarity")

        case .preamp:
          update(&_preamp, value: property.value, key: "preamp")

        case .source:
          update(&_source, value: property.value, key: "source")

        case .sourceRxAnt:
          update(&_sourceRxAnt, value: property.value, key: "sourceRxAnt")

        case .sourceSlice:
          update(&_sourceSlice, value: property.value.iValue(), key: "sourceSlice")

        case .sourceTxAnt:
          update(&_sourceTxAnt, value: property.value, key: "sourceTxAnt")

        case .speed:
          update(&_speed, value: property.value.iValue(), key: "speed")

        case .stopBits:
          update(&_stopBits, value: property.value.iValue(), key: "stopBits")

        case .usbLog:
          update(&_usbLog, value: property.value.bValue(), key: "usbLog")

          //                case .usbLogLine:
          //                    willChangeValue(forKey: "usbLogLine")
          //                    _usbLogLine = property.value
          //                    didChangeValue(forKey: "usbLogLine")
          
        }
      }
      
    } else {
      
      // NO, log the error
      Log.sharedInstance.msg("Status type (\(properties[0])) != Cable type (\(cableType)))", level: .error, function: #function, file: #file, line: #line)
    }
    
    // is the waterfall initialized?
    if !_initialized {
      
      // YES, the Radio (hardware) has acknowledged this UsbCable
      _initialized = true
      
      // notify all observers
      NC.post(.usbCableHasBeenAdded, object: self as Any?)
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
// MARK: - UsbCable Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - UsbCable tokens
// --------------------------------------------------------------------------------

extension UsbCable {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _autoReport: Bool {
    get { return _q.sync { __autoReport } }
    set { _q.sync(flags: .barrier) {__autoReport = newValue } } }
  
  internal var _band: String {
    get { return _q.sync { __band } }
    set { _q.sync(flags: .barrier) {__band = newValue } } }
  
  internal var _dataBits: Int {
    get { return _q.sync { __dataBits } }
    set { _q.sync(flags: .barrier) {__dataBits = newValue } } }
  
  internal var _enable: Bool {
    get { return _q.sync { __enable } }
    set { _q.sync(flags: .barrier) {__enable = newValue } } }
  
  internal var _flowControl: String {
    get { return _q.sync { __flowControl } }
    set { _q.sync(flags: .barrier) {__flowControl = newValue } } }
  
  internal var _name: String {
    get { return _q.sync { __name } }
    set { _q.sync(flags: .barrier) {__name = newValue } } }
  
  internal var _parity: String {
    get { return _q.sync { __parity } }
    set { _q.sync(flags: .barrier) {__parity = newValue } } }
  
  internal var _pluggedIn: Bool {
    get { return _q.sync { __pluggedIn } }
    set { _q.sync(flags: .barrier) {__pluggedIn = newValue } } }
  
  internal var _polarity: String {
    get { return _q.sync { __polarity } }
    set { _q.sync(flags: .barrier) {__polarity = newValue } } }
  
  internal var _preamp: String {
    get { return _q.sync { __preamp } }
    set { _q.sync(flags: .barrier) {__preamp = newValue } } }
  
  internal var _source: String {
    get { return _q.sync { __source } }
    set { _q.sync(flags: .barrier) {__source = newValue } } }
  
  internal var _sourceRxAnt: String {
    get { return _q.sync { __sourceRxAnt } }
    set { _q.sync(flags: .barrier) {__sourceRxAnt = newValue } } }
  
  internal var _sourceSlice: Int {
    get { return _q.sync { __sourceSlice } }
    set { _q.sync(flags: .barrier) {__sourceSlice = newValue } } }
  
  internal var _sourceTxAnt: String {
    get { return _q.sync { __sourceTxAnt } }
    set { _q.sync(flags: .barrier) {__sourceTxAnt = newValue } } }
  
  internal var _speed: Int {
    get { return _q.sync { __speed } }
    set { _q.sync(flags: .barrier) {__speed = newValue } } }
  
  internal var _stopBits: Int {
    get { return _q.sync { __stopBits } }
    set { _q.sync(flags: .barrier) {__stopBits = newValue } } }
  
  internal var _usbLog: Bool {
    get { return _q.sync { __usbLog } }
    set { _q.sync(flags: .barrier) {__usbLog = newValue } } }
  
  //    internal var _usbLogLine: String {
  //        get { return _usbCableQ.sync { __usbLogLine } }
  //        set { _usbCableQ.sync(flags: .barrier) {__usbLogLine = newValue } } }
  //
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // None
  
  // ----------------------------------------------------------------------------
  // MARK: - UsbCable tokens
  
  internal enum Token : String {
    case autoReport       = "auto_report"
    case band
    case cableType        = "type"
    case dataBits         = "data_bits"
    case enable
    case flowControl      = "flow_control"
    case name
    case parity
    case pluggedIn        = "plugged_in"
    case polarity
    case preamp
    case source
    case sourceRxAnt      = "source_rx_ant"
    case sourceSlice      = "source_slice"
    case sourceTxAnt      = "source_tx_ant"
    case speed
    case stopBits         = "stop_bits"
    case usbLog           = "log"
    //        case usbLogLine = "log_line"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - UsbCable related enum
  
  public enum UsbCableType: String {
    case bcd
    case bit
    case cat
    case dstar
    case invalid
    case ldpa
  }
  
}

