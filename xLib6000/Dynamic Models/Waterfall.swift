//
//  Waterfall.swift
//  xLib6000
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

public typealias WaterfallId = UInt32

// --------------------------------------------------------------------------------
// MARK: - WaterfallStreamHandler protocol
//
// --------------------------------------------------------------------------------

public protocol WaterfallStreamHandler      : class {
  
  // method to process Waterfall data stream
  func streamHandler(_ dataFrame: WaterfallFrame ) -> Void
}

// --------------------------------------------------------------------------------
// MARK: - Waterfall Class implementation
//
//      creates a Waterfall instance to be used by a Client to support the
//      processing of a Waterfall. Waterfall objects are added / removed by the
//      incoming TCP messages. Waterfall objects periodically receive Waterfall
//      data in a UDP stream.
//
// --------------------------------------------------------------------------------

public final class Waterfall                : NSObject, StatusParser, PropertiesParser, VitaProcessor {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : WaterfallId   = 0             // Waterfall Id (StreamId)

  public private(set) var lastTimecode      = 0                             // Time code of last frame received
  public private(set) var droppedPackets    = 0                             // Number of dropped (out of sequence) packets

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio hardware

  private var _dataframes                   = [WaterfallFrame]()
  private var _dataframeIndex               = 0
  
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
  private weak var _delegate                : WaterfallStreamHandler?       // Delegate for Waterfall stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a Waterfall status message
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
    _dataframes.append(WaterfallFrame(frameSize: 4096))
    _dataframes.append(WaterfallFrame(frameSize: 4096))

    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ
  
  /// Parse Waterfall key/value pairs
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
      // Known keys, in alphabetical order
      switch token {
        
      case .autoBlackEnabled:
        _api.update(self, property: &_autoBlackEnabled, value: property.value.bValue(), key: "autoBlackEnabled")

      case .blackLevel:
        _api.update(self, property: &_blackLevel, value: property.value.iValue(), key: "blackLevel")

      case .colorGain:
        _api.update(self, property: &_colorGain, value: property.value.iValue(), key: "colorGain")

      case .gradientIndex:
        _api.update(self, property: &_gradientIndex, value: property.value.iValue(), key: "gradientIndex")

      case .lineDuration:
        _api.update(self, property: &_lineDuration, value: property.value.iValue(), key: "lineDuration")

      case .panadapterId:     // does not have leading "0x"
        _api.update(self, property: &_panadapterId, value: UInt32(property.value, radix: 16) ?? 0, key: "panadapterId")

      case .available, .band, .bandwidth, .capacity, .center, .daxIq, .daxIqRate,
           .loopA, .loopB, .rfGain, .rxAnt, .wide, .xPixels, .xvtr:
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

  // ----------------------------------------------------------------------------
  // MARK: - VitaProcessor protocol methods
  
  //      called by Radio on the streamQ
  //
  //      The payload of the incoming Vita struct is converted to a WaterfallFrame and
  //      passed to the Waterfall Stream Handler
  
  /// Process the Waterfall Vita struct
  ///
  /// - Parameters:
  ///   - vita:       a Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    // use the next dataframe
    _dataframeIndex = (_dataframeIndex + 1) % 2

    // convert the Vita struct to s WaterfallFrame
    _dataframes[_dataframeIndex].populate(vita: vita)
    
    // If the time code is out-of-sequence, ignore the packet
    if _dataframes[_dataframeIndex].timeCode < lastTimecode {
      droppedPackets += 1
      Log.sharedInstance.msg("Missing packet(s), timecode: \(_dataframes[_dataframeIndex].timeCode) < last timecode: \(lastTimecode)", level: .warning, function: #function, file: #file, line: #line)
      // out of sequence, ignore this packet
      return
    }
    lastTimecode = _dataframes[_dataframeIndex].timeCode;
    
    // save the auto black level
    _autoBlackLevel = _dataframes[_dataframeIndex].autoBlackLevel
    
    // Pass the data frame to this Waterfall's delegate
    delegate?.streamHandler(_dataframes[_dataframeIndex])
  }
}

// ------------------------------------------------------------------------------
// MARK: - WaterfallFrame class implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Waterfall vitaHandler
//

public class WaterfallFrame {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var firstBinFreq      : CGFloat   = 0.0               // Frequency of first Bin (Hz)
  public private(set) var binBandwidth      : CGFloat   = 0.0               // Bandwidth of a single bin (Hz)
  public private(set) var lineDuration      = 0                             // Duration of this line (ms)
  public private(set) var lineHeight        = 0                             // Height of frame (pixels)
  public private(set) var timeCode          = 0                             // Time code
  public private(set) var autoBlackLevel    : UInt32 = 0                    // Auto black level
  public private(set) var numberOfBins      = 0                             // Number of bins
  public var bins                           = [UInt16]()                    // Array of bin values
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private struct WaterfallPayload {                                         // struct to mimic payload layout
    var firstBinFreq                        : UInt64                        // 8 bytes
    var binBandwidth                        : UInt64                        // 8 bytes
    var lineDuration                        : UInt32                        // 4 bytes
    var numberOfBins                        : UInt16                        // 2 bytes
    var lineHeight                          : UInt16                        // 2 bytes
    var timeCode                            : UInt32                        // 4 bytes
    var autoBlackLevel                      : UInt32                        // 4 bytes
  }
  
  private let kByteOffsetToBins = 32              // Bins are located 32 bytes into payload
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a WaterfallFrame
  ///
  /// - Parameter frameSize:    max number of Waterfall samples
  ///
  public init(frameSize: Int) {
    
    // allocate the bins array
    self.bins = [UInt16](repeating: 0, count: frameSize)
  }
  /// Convert a Vita object to a WaterfallFrame object
  ///
  /// - Parameter vita:         incoming Vita object
  ///
  public func populate(vita: Vita) {
    
    let payloadPtr = UnsafeRawPointer(vita.payloadData)

    // map the payload to the WaterfallPayload struct
    let p = payloadPtr.bindMemory(to: WaterfallPayload.self, capacity: 1)
    
    // byte swap and convert each payload component
    firstBinFreq = CGFloat(CFSwapInt64BigToHost(p.pointee.firstBinFreq)) / 1.048576E6
    binBandwidth = CGFloat(CFSwapInt64BigToHost(p.pointee.binBandwidth)) / 1.048576E6
    lineDuration = Int( CFSwapInt32BigToHost(p.pointee.lineDuration) )
    lineHeight = Int( CFSwapInt16BigToHost(p.pointee.lineHeight) )
    timeCode = Int( CFSwapInt32BigToHost(p.pointee.timeCode) )
    autoBlackLevel = CFSwapInt32BigToHost(p.pointee.autoBlackLevel)
    numberOfBins = Int( CFSwapInt16BigToHost(p.pointee.numberOfBins) )
    
    // get a pointer to the data in the payload
    let binsPtr = payloadPtr.advanced(by: kByteOffsetToBins).bindMemory(to: UInt16.self, capacity: numberOfBins)
    
    // Swap the byte ordering of the data & place it in the bins
    for i in 0..<numberOfBins * lineHeight {
      bins[i] = CFSwapInt16BigToHost(binsPtr.advanced(by: i).pointee)
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Waterfall Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Waterfall tokens
// --------------------------------------------------------------------------------

extension Waterfall {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
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
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var autoBlackLevel: UInt32 {
    return _autoBlackLevel }
  
  @objc dynamic public var panadapterId: PanadapterId {
    return _panadapterId }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var delegate: WaterfallStreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Waterfall tokens
  
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
    case wide
    case xPixels              = "x_pixels"
    case xvtr
  }
}
