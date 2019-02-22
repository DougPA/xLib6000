//
//  Waterfall.swift
//  xLib6000
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation
import os

public typealias WaterfallId = UInt32

/// Waterfall Class implementation
///
///      creates a Waterfall instance to be used by a Client to support the
///      processing of a Waterfall. Waterfall objects are added / removed by the
///      incoming TCP messages. Waterfall objects periodically receive Waterfall
///      data in a UDP stream.
///
public final class Waterfall                : NSObject, DynamicModelWithStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var isStreaming                    = false
  
  public private(set) var id                : WaterfallId   = 0             // Waterfall Id (StreamId)
//  public private(set) var lastTimecode      = -1                            // Time code of last frame received
  public private(set) var expectedIndex     = -1                            // Frame index of next Vita payload
  public private(set) var droppedPackets    = 0                             // Number of dropped (out of sequence) packets

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "Waterfall")
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _waterfallframes                   = [WaterfallFrame]()
  private var _index               = 0
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __autoBlackEnabled            = false                         // State of auto black
  private var __autoBlackLevel              : UInt32 = 0                    // Radio generated black level
  private var __blackLevel                  = 0                             // Setting of black level (1 -> 100)
  private var __colorGain                   = 0                             // Setting of color gain (1 -> 100)
  private var __gradientIndex               = 0                             // Index of selected color gradient
  private var __lineDuration                = 0                             // Line duration (milliseconds)
  private var __panadapterId                : PanadapterId = 0              // Panadaptor above this waterfall
  //
  private weak var _delegate                : StreamHandler?                // Delegate for Waterfall stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  private let _numberOfDataFrames           = 10
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol class methods
  
  /// Parse a Waterfall status message
  ///
  ///   StatusParser protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format: <"waterfall", ""> <id, ""> <"x_pixels", value> <"center", value> <"bandwidth", value> <"line_duration", value>
    //          <"rfgain", value> <"rxant", value> <"wide", 1|0> <"loopa", 1|0> <"loopb", 1|0> <"band", value> <"daxiq", value>
    //          <"daxiq_rate", value> <"capacity", value> <"available", value> <"panadapter", streamId>=40000000 <"color_gain", value>
    //          <"auto_black", 1|0> <"black_level", value> <"gradient_index", value> <"xvtr", value>
    //      OR
    // Format: <"waterfall", ""> <id, ""> <"rxant", value> <"loopa", 1|0> <"loopb", 1|0>
    //      OR
    // Format: <"waterfall", ""> <id, ""> <"rfgain", value>
    //      OR
    // Format: <"waterfall", ""> <id, ""> <"daxiq", value> <"daxiq_rate", value> <"capacity", value> <"available", value>
    
    // get the streamId (remove the "0x" prefix)
    if let streamId = UInt32(String(keyValues[1].key.dropFirst(2)), radix: 16) {
      
      // is the Waterfall in use?
      if inUse {
        
        // YES, does it exist?
        if radio.waterfalls[streamId] == nil {
          
          // NO, Create a Waterfall & add it to the Waterfalls collection
          radio.waterfalls[streamId] = Waterfall(id: streamId, queue: queue)
        }
        // pass the key values to the Waterfall for parsing (dropping the Type and Id)
        radio.waterfalls[streamId]!.parseProperties(Array(keyValues.dropFirst(2)))
        
      } else {
        
        // notify all observers
        NC.post(.waterfallWillBeRemoved, object: radio.waterfalls[streamId] as Any?)
        
        // remove the associated Panadapter
        radio.panadapters[radio.waterfalls[streamId]!.panadapterId] = nil
        
        // remove the Waterfall
        radio.waterfalls[streamId] = nil
      }
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Waterfall
  ///
  /// - Parameters:
  ///   - streamId:           a Waterfall Id
  ///   - queue:              Concurrent queue
  ///
  public init(id: WaterfallId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue
    
    // allocate two dataframes
    for _ in 0..<_numberOfDataFrames {
      _waterfallframes.append(WaterfallFrame(frameSize: 4096))
    }

    super.init()
    
    isStreaming = false
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Protocol instance methods
  
  /// Parse Waterfall key/value pairs
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown keys
      guard let token = Token(rawValue: property.key) else {
        
        // unknown Key, log it and ignore the Key
        os_log("Unknown Waterfall token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .autoBlackEnabled:
        willChangeValue(for: \.autoBlackEnabled)
        _autoBlackEnabled = property.value.bValue
        didChangeValue(for: \.autoBlackEnabled)

      case .blackLevel:
        willChangeValue(for: \.blackLevel)
        _blackLevel = property.value.iValue
        didChangeValue(for: \.blackLevel)

      case .colorGain:
        willChangeValue(for: \.colorGain)
        _colorGain = property.value.iValue
        didChangeValue(for: \.colorGain)

      case .gradientIndex:
         willChangeValue(for: \.gradientIndex)
        _gradientIndex = property.value.iValue
        didChangeValue(for: \.gradientIndex)

      case .lineDuration:
        willChangeValue(for: \.lineDuration)
        _lineDuration = property.value.iValue
        didChangeValue(for: \.lineDuration)

      case .panadapterId:     // does not have leading "0x"
        willChangeValue(for: \.panadapterId)
        _panadapterId = UInt32(property.value, radix: 16) ?? 0
        didChangeValue(for: \.panadapterId)

      case .available, .band, .bandwidth, .bandZoomEnabled, .capacity, .center, .daxIq, .daxIqRate,
           .loopA, .loopB, .rfGain, .rxAnt, .segmentZoomEnabled, .wide, .xPixels, .xvtr:
        // ignored here
        break
      }
    }
    // is the waterfall initialized?
    if !_initialized && panadapterId != 0 {
      
      // YES, the Radio (hardware) has acknowledged this Waterfall
      _initialized = true
      
      // notify all observers
      NC.post(.waterfallHasBeenAdded, object: self as Any?)
    }
  }
  /// Process the Waterfall Vita struct
  ///
  ///   VitaProcessor protocol method, executes on the streamQ
  ///      The payload of the incoming Vita struct is converted to a WaterfallFrame and
  ///      passed to the Waterfall Stream Handler, called by Radio
  ///
  /// - Parameters:
  ///   - vita:       a Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    // convert the Vita struct and accumulate a WaterfallFrame
    if _waterfallframes[_index].accumulate(vita: vita, expectedIndex: &expectedIndex) {
      
      expectedIndex += 1

      // save the auto black level
      _autoBlackLevel = _waterfallframes[_index].autoBlackLevel
      
      // Pass the data frame to this Waterfall's delegate
      delegate?.streamHandler(_waterfallframes[_index])

      // use the next dataframe
      _index = (_index + 1) % _numberOfDataFrames
    }
  }
}

extension Waterfall {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _autoBlackEnabled: Bool {
    get { return _q.sync { __autoBlackEnabled } }
    set { _q.sync(flags: .barrier) {__autoBlackEnabled = newValue } } }
  
  internal var _autoBlackLevel: UInt32 {
    get { return _q.sync { __autoBlackLevel } }
    set { _q.sync(flags: .barrier) { __autoBlackLevel = newValue } } }
  
  internal var _blackLevel: Int {
    get { return _q.sync { __blackLevel } }
    set { _q.sync(flags: .barrier) {__blackLevel = newValue } } }
  
  internal var _colorGain: Int {
    get { return _q.sync { __colorGain } }
    set { _q.sync(flags: .barrier) {__colorGain = newValue } } }
  
  internal var _gradientIndex: Int {
    get { return _q.sync { __gradientIndex } }
    set { _q.sync(flags: .barrier) {__gradientIndex = newValue } } }
  
  internal var _lineDuration: Int {
    get { return _q.sync { __lineDuration } }
    set { _q.sync(flags: .barrier) {__lineDuration = newValue } } }
  
  internal var _panadapterId: PanadapterId {
    get { return _q.sync { __panadapterId } }
    set { _q.sync(flags: .barrier) { __panadapterId = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  @objc dynamic public var autoBlackLevel: UInt32 {
    return _autoBlackLevel }
  
  @objc dynamic public var panadapterId: PanadapterId {
    return _panadapterId }
  
  // ----------------------------------------------------------------------------
  // MARK: - NON Public properties (KVO compliant)
  
  public var delegate: StreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Tokens
  
  /// Properties
  ///
  internal enum Token : String {
    // on Waterfall
    case autoBlackEnabled     = "auto_black"
    case blackLevel           = "black_level"
    case colorGain            = "color_gain"
    case gradientIndex        = "gradient_index"
    case lineDuration         = "line_duration"
    // unused here
    case available
    case band
    case bandZoomEnabled      = "band_zoom"
    case bandwidth
    case capacity
    case center
    case daxIq                = "daxiq"
    case daxIqRate            = "daxiq_rate"
    case loopA                = "loopa"
    case loopB                = "loopb"
    case panadapterId         = "panadapter"
    case rfGain               = "rfgain"
    case rxAnt                = "rxant"
    case segmentZoomEnabled   = "segment_zoom"
    case wide
    case xPixels              = "x_pixels"
    case xvtr
  }
}

