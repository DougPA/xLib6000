//
//  BandSetting.swift
//  xLib6000
//
//  Created by Douglas Adams on 4/6/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Foundation

public typealias BandId = Int

/// BandSetting Class implementation
///
///      creates a BandSetting instance to be used by a Client to support the
///      processing of the band settings. BandSetting objects are added, removed and
///      updated by the incoming TCP messages. They are collected in the bandSettings
///      collection on the Radio object.
///
public final class BandSetting                : NSObject, DynamicModel {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : BandId = 0                    // Id that uniquely identifies this BandSetting
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __accTxEnabled                = false                           //
  private var __accTxReqEnabled             = false                           //
  private var __bandName                    = ""                              //
  private var __hwAlcEnabled                = false                           //
  private var __inhibit                     = false                           //
  private var __rcaTxReqEnabled             = false                           //
  private var __rfPower                     = 0                               //
  private var __tunePower                   = 0                               //
  private var __tx1Enabled                  = false                           //
  private var __tx2Enabled                  = false                           //
  private var __tx3Enabled                  = false                           //
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods
  
  /// Parse a BandSetting status message
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
    // Format:  <band, > <bandId, > <"band_name", name> <"rfpower", power> <"tunepower", tunepower> <"hwalc_enabled", 0/1> <"inhinit", 0/1>
    //          <band, > <bandId, > <"band_name", name> <"acc_txreq_enabled", 0/1> <"rca_txreq_enabled", 0/1> <"acc_tx_enabled", 0/1> <"tx1_enabled", 0/1> <"tx2_enabled", 0/1> <"tx3_enabled", 0/1>

    // get the BandId
    if let bandId = Int(keyValues[0].key) {
      
      // is it active?
      if inUse {
        // YES, does the BandSetting exist?
        if radio.bandSettings[bandId] == nil {
          
          // NO, create a new BandSetting & add it to the BandSettings collection
          radio.bandSettings[bandId] = BandSetting(id: bandId, queue: queue)
        }
        // pass the remaining key values to the BandSetting for parsing
        radio.bandSettings[bandId]!.parseProperties( Array(keyValues.dropFirst(1)) )
      
      } else {
        // NO, notify all observers
        //      NC.post(.bandSettingWillBeRemoved, object: radio.bandSettings[bandId] as Any?)
        
        // remove it
        radio.bandSettings[bandId] = nil
      }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a BandSetting
  ///
  /// - Parameters:
  ///   - id:                 an Band Id
  ///   - queue:              Concurrent queue
  ///
  public init(id: BandId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods
  
  /// Parse BandSetting key/value pairs
  ///
  ///   PropertiesParser Protocol method, , executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        // log it and ignore the Key
        _log.msg("Unknown BandSetting token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .accTxEnabled:
        willChangeValue(for: \.accTxEnabled)
        _accTxEnabled = property.value.bValue
        didChangeValue(for: \.accTxEnabled)
        
      case .accTxReqEnabled:
        willChangeValue(for: \.accTxReqEnabled)
        _accTxReqEnabled = property.value.bValue
        didChangeValue(for: \.accTxReqEnabled)
        
      case .bandName:
        willChangeValue(for: \.bandName)
        _bandName = property.value
        didChangeValue(for: \.bandName)
        
      case .hwAlcEnabled:
        willChangeValue(for: \.hwAlcEnabled)
        _hwAlcEnabled = property.value.bValue
        didChangeValue(for: \.hwAlcEnabled)
        
      case .inhibit:
        willChangeValue(for: \.inhibit)
        _inhibit = property.value.bValue
        didChangeValue(for: \.inhibit)
        
      case .rcaTxReqEnabled:
        willChangeValue(for: \.rcaTxReqEnabled)
        _rcaTxReqEnabled = property.value.bValue
        didChangeValue(for: \.rcaTxReqEnabled)
        
      case .rfPower:
        willChangeValue(for: \.rfPower)
        _rfPower = property.value.iValue
        didChangeValue(for: \.rfPower)
        
      case .tunePower:
        willChangeValue(for: \.tunePower)
        _tunePower = property.value.iValue
        didChangeValue(for: \.tunePower)
        
      case .tx1Enabled:
        willChangeValue(for: \.tx1Enabled)
        _tx1Enabled = property.value.bValue
        didChangeValue(for: \.tx1Enabled)
        
      case .tx2Enabled:
        willChangeValue(for: \.tx2Enabled)
        _tx2Enabled = property.value.bValue
        didChangeValue(for: \.tx2Enabled)
        
      case .tx3Enabled:
        willChangeValue(for: \.tx3Enabled)
        _tx3Enabled = property.value.bValue
        didChangeValue(for: \.tx3Enabled)
      }
    }
    // is the BandSetting initialized?
    if _initialized == false {
      
      // YES, the Radio (hardware) has acknowledged this BandSetting
      _initialized = true
      
      // notify all observers
//      NC.post(.amplifierHasBeenAdded, object: self as Any?)
    }
  }
}

extension BandSetting {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _accTxEnabled: Bool {
    get { return _q.sync { __accTxEnabled } }
    set { _q.sync(flags: .barrier) {__accTxEnabled = newValue } } }
  
  internal var _accTxReqEnabled: Bool {
    get { return _q.sync { __accTxReqEnabled } }
    set { _q.sync(flags: .barrier) {__accTxReqEnabled = newValue } } }
  
  internal var _bandName: String {
    get { return _q.sync { __bandName } }
    set { _q.sync(flags: .barrier) {__bandName = newValue } } }
  
  internal var _hwAlcEnabled: Bool {
    get { return _q.sync { __hwAlcEnabled } }
    set { _q.sync(flags: .barrier) {__hwAlcEnabled = newValue } } }
  
  internal var _inhibit: Bool {
    get { return _q.sync { __inhibit } }
    set { _q.sync(flags: .barrier) {__inhibit = newValue } } }
  
  internal var _rcaTxReqEnabled: Bool {
    get { return _q.sync { __rcaTxReqEnabled } }
    set { _q.sync(flags: .barrier) {__rcaTxReqEnabled = newValue } } }
  
  internal var _rfPower: Int {
    get { return _q.sync { __rfPower } }
    set { _q.sync(flags: .barrier) {__rfPower = newValue } } }
  
  internal var _tunePower: Int {
    get { return _q.sync { __tunePower } }
    set { _q.sync(flags: .barrier) {__tunePower = newValue } } }

  internal var _tx1Enabled: Bool {
    get { return _q.sync { __tx1Enabled } }
    set { _q.sync(flags: .barrier) {__tx1Enabled = newValue } } }
  
  internal var _tx2Enabled: Bool {
    get { return _q.sync { __tx2Enabled } }
    set { _q.sync(flags: .barrier) {__tx2Enabled = newValue } } }
  
  internal var _tx3Enabled: Bool {
    get { return _q.sync { __tx3Enabled } }
    set { _q.sync(flags: .barrier) {__tx3Enabled = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// BandSetting Properties
  ///
  internal enum Token : String {
    case accTxEnabled                       = "acc_tx_enabled"
    case accTxReqEnabled                    = "acc_txreq_enable"
    case bandName                           = "band_name"
    case hwAlcEnabled                       = "hwalc_enabled"
    case inhibit
    case rcaTxReqEnabled                    = "rca_txreq_enable"
    case rfPower                            = "rfpower"
    case tunePower                          = "tunepower"
    case tx1Enabled                         = "tx1_enabled"
    case tx2Enabled                         = "tx2_enabled"
    case tx3Enabled                         = "tx3_enabled"
  }
}
