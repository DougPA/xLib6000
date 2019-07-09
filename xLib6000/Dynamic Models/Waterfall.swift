//
//  Waterfall.swift
//  xLib6000
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

public typealias WaterfallId = StreamId

/// Waterfall Class implementation
///
///      creates a Waterfall instance to be used by a Client to support the
///      processing of a Waterfall. Waterfall objects are added / removed by the
///      incoming TCP messages. Waterfall objects periodically receive Waterfall
///      data in a UDP stream. They are collected in the waterfalls collection
///      on the Radio object.
///
public final class Waterfall                : NSObject, DynamicModelWithStream {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var isStreaming                    = false
  
  public private(set) var streamId          : WaterfallId = 0               // Waterfall StreamId
  public private(set) var packetFrame       = -1                            // Frame index of next Vita payload
  public private(set) var droppedPackets    = 0                             // Number of dropped (out of sequence) packets

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _log                          = Log.sharedInstance
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _waterfallframes                   = [WaterfallFrame]()
  private var _index               = 0
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __autoBlackEnabled            = false                         // State of auto black
  private var __autoBlackLevel              : UInt32 = 0                    // Radio generated black level
  private var __blackLevel                  = 0                             // Setting of black level (1 -> 100)
  private var __clientHandle                : Handle = 0                    // Client owning this Waterfall (V3 only)
  private var __colorGain                   = 0                             // Setting of color gain (1 -> 100)
  private var __daxIqChannel                = 0                             // DAX IQ channel number (0=none)
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
    // Format: <"waterfall", ""> <streamId, ""> <"client_handle", ClientHandle> <"x_pixels", value> <"center", value> <"bandwidth", value> <"line_duration", value>
    //          <"rfgain", value> <"rxant", value> <"wide", 1|0> <"loopa", 1|0> <"loopb", 1|0> <"band", value> <"daxiq", value>
    //          <"daxiq_rate", value> <"capacity", value> <"available", value> <"panadapter", streamId>=40000000 <"color_gain", value>
    //          <"auto_black", 1|0> <"black_level", value> <"gradient_index", value> <"xvtr", value>
    //      OR
    // Format: <"waterfall", ""> <streamId, ""> <"rxant", value> <"loopa", 1|0> <"loopb", 1|0>
    //      OR
    // Format: <"waterfall", ""> <streamId, ""> <"rfgain", value>
    //      OR
    // Format: <"waterfall", ""> <streamId, ""> <"daxiq_channel", value>
    
    // get the streamId
    if let streamId = keyValues[1].key.streamId {
      
      // is the Waterfall in use?
      if inUse {
        
        // YES, does it exist?
        if radio.waterfalls[streamId] == nil {
          
          // NO, Create a Waterfall & add it to the Waterfalls collection
          radio.waterfalls[streamId] = Waterfall(streamId: streamId, queue: queue)
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
  public init(streamId: WaterfallId, queue: DispatchQueue) {
    
    self.streamId = streamId
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
      
      // check for unknown Keys
      guard let token = Token(rawValue: property.key) else {
        // log it and ignore the Key
        _log.msg("Unknown Waterfall token: \(property.key) = \(property.value)", level: .warning, function: #function, file: #file, line: #line)
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

      case .clientHandle:
        willChangeValue(for: \.clientHandle)
        _clientHandle = property.value.handle ?? 0
        didChangeValue(for: \.clientHandle)
        
      case .colorGain:
        willChangeValue(for: \.colorGain)
        _colorGain = property.value.iValue
        didChangeValue(for: \.colorGain)

      case .daxIqChannel:
        willChangeValue(for: \.daxIqChannel)
        _daxIqChannel = property.value.iValue
        didChangeValue(for: \.daxIqChannel)
        
      case .gradientIndex:
         willChangeValue(for: \.gradientIndex)
        _gradientIndex = property.value.iValue
        didChangeValue(for: \.gradientIndex)

      case .lineDuration:
        willChangeValue(for: \.lineDuration)
        _lineDuration = property.value.iValue
        didChangeValue(for: \.lineDuration)

      case .panadapterId:
        willChangeValue(for: \.panadapterId)
        _panadapterId = property.value.streamId ?? 0
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
    if _waterfallframes[_index].accumulate(vita: vita, expectedFrame: &packetFrame) {

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
  
  internal var _clientHandle: Handle {
    get { return _q.sync { __clientHandle } }
    set { _q.sync(flags: .barrier) { __clientHandle = newValue } } }
  
  internal var _colorGain: Int {
    get { return _q.sync { __colorGain } }
    set { _q.sync(flags: .barrier) {__colorGain = newValue } } }
  
  internal var _daxIqChannel: Int {
    get { return _q.sync { __daxIqChannel } }
    set { _q.sync(flags: .barrier) { __daxIqChannel = newValue } } }
  
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
  
  @objc dynamic public var clientHandle: Handle {
    return _clientHandle }
  
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
    case clientHandle         = "client_handle"
    case colorGain            = "color_gain"
    case daxIqChannel         = "daxiq_channel"
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

