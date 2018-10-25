//
//  Panadapter.swift
//  xLib6000
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation
import os
import simd

public typealias PanadapterId = UInt32

// --------------------------------------------------------------------------------
// MARK: - Panadapter implementation
//
//      creates a Panadapter instance to be used by a Client to support the
//      processing of a Panadapter. Panadapter objects are added / removed by the
//      incoming TCP messages. Panadapter objects periodically receive Panadapter
//      data in a UDP stream.
//
// --------------------------------------------------------------------------------

public final class Panadapter               : NSObject, DynamicModelWithStream {
  
  static let kMaxBins                       = 5120
//  static let daxIqChannels                  = ["None", "1", "2", "3", "4"]
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var id                : PanadapterId = 0              // Panadapter Id (StreamId)
  
  public private(set) var lastFrameIndex    = 0                             // Frame index of previous Vita payload
  public private(set) var droppedPackets    = 0                             // Number of dropped (out of sequence) packets
  
  @objc dynamic public let daxIqChoices     = Api.daxIqChannels
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "Panadapter")
  private let _api                          = Api.sharedInstance            // reference to the API singleton
  private let _q                            : DispatchQueue                 // Q for object synchronization
  private var _initialized                  = false                         // True if initialized by Radio (hardware)

  private var _dataframes                   = [PanadapterFrame]()
  private var _dataframeIndex               = 0
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __antList                     = [String]()                    // Available antenna choices
  private var __autoCenterEnabled           = false                         //
  private var __average                     = 0                             // Setting of average (1 -> 100)
  private var __band                        = ""                            // Band encompassed by this pan
  private var __bandwidth                   = 0                             // Bandwidth in Hz
  private var __bandZoomEnabled             = false                         //
  private var __center                      = 0                             // Center in Hz
  private var __daxIqChannel                = 0                             // DAX IQ channel number (0=none)
  private var __fps                         = 0                             // Refresh rate (frames/second)
  private var __loopAEnabled                = false                         // Enable LOOPA for RXA
  private var __loopBEnabled                = false                         // Enable LOOPB for RXB
  private var __loggerDisplayEnabled        = false                         // Enable pan data to logger
  private var __loggerDisplayIpAddress      = ""                            // Logger Ip Address
  private var __loggerDisplayPort           = 0                             // Logger Port number
  private var __loggerDisplayRadioNumber    = 0                             // Logger Radio number
  private var __maxBw                       = 0                             // Maximum bandwidth
  private var __minBw                       = 0                             // Minimum bandwidthl
  private var __maxDbm                      : CGFloat = 0.0                 // Maximum dBm level
  private var __minDbm                      : CGFloat = 0.0                 // Minimum dBm level
  private var __preamp                      = ""                            // Label of preselector selected
  private var __rfGain                      = 0                             // RF Gain of preamp/attenuator
  private var __rfGainHigh                  = 0                             // RF Gain high value
  private var __rfGainLow                   = 0                             // RF Gain low value
  private var __rfGainStep                  = 0                             // RF Gain step value
  private var __rfGainValues                = ""                            // Possible Rf Gain values
  private var __rxAnt                       = ""                            // Receive antenna name
  private var __segmentZoomEnabled          = false                         //
  private var __waterfallId                 : UInt32 = 0                    // Waterfall below this Panadapter
  private var __weightedAverageEnabled      = false                         // Enable weighted averaging
  private var __wide                        = false                         // Preselector state
  private var __wnbEnabled                  = false                         // Wideband noise blanking enabled
  private var __wnbLevel                    = 0                             // Wideband noise blanking level
  private var __wnbUpdating                 = false                         // WNB is updating
  private var __xPixels                     : CGFloat = 0                   // frame width
  private var __yPixels                     : CGFloat = 0                   // frame height
  private var __xvtrLabel                   = ""                            // Label of selected XVTR profile
  //
  private weak var _delegate                : StreamHandler?                // Delegate for Panadapter stream
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------

  // ------------------------------------------------------------------------------
  // MARK: - Class methods
  
  // ----------------------------------------------------------------------------
  //      StatusParser Protocol method
  //      called by Radio.parseStatusMessage(_:), executes on the parseQ
  
  /// Parse a Panadapter status message
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool = true) {
    // Format: <"pan", ""> <id, ""> <"wnb", 1|0> <"wnb_level", value> <"wnb_updating", 1|0> <"x_pixels", value> <"y_pixels", value>
    //          <"center", value>, <"bandwidth", value> <"min_dbm", value> <"max_dbm", value> <"fps", value> <"average", value>
    //          <"weighted_average", 1|0> <"rfgain", value> <"rxant", value> <"wide", 1|0> <"loopa", 1|0> <"loopb", 1|0>
    //          <"band", value> <"daxiq", 1|0> <"daxiq_rate", value> <"capacity", value> <"available", value> <"waterfall", streamId>
    //          <"min_bw", value> <"max_bw", value> <"xvtr", value> <"pre", value> <"ant_list", value>
    //      OR
    // Format: <"pan", ""> <id, ""> <"center", value> <"xvtr", value>
    //      OR
    // Format: <"pan", ""> <id, ""> <"rxant", value> <"loopa", 1|0> <"loopb", 1|0> <"ant_list", value>
    //      OR
    // Format: <"pan", ""> <id, ""> <"rfgain", value> <"pre", value>
    //
    // Format: <"pan", ""> <id, ""> <"wnb", 1|0> <"wnb_level", value> <"wnb_updating", 1|0>
    //      OR
    // Format: <"pan", ""> <id, ""> <"daxiq", value> <"daxiq_rate", value> <"capacity", value> <"available", value>
    
    // get the streamId (remove the "0x" prefix)
    if let streamId = UInt32(String(keyValues[1].key.dropFirst(2)), radix: 16) {
      
      // is the Panadapter in use?
      if inUse {
        
        // YES, does it exist?
        if radio.panadapters[streamId] == nil {
          
          // NO, Create a Panadapter & add it to the Panadapters collection
          radio.panadapters[streamId] = Panadapter(id: streamId, queue: queue)
        }
        // pass the key values to the Panadapter for parsing (dropping the Type and Id)
        radio.panadapters[streamId]!.parseProperties(Array(keyValues.dropFirst(2)))
        
      } else {
        
        // notify all observers
        NC.post(.panadapterWillBeRemoved, object: radio.panadapters[streamId] as Any?)
      }
    }
  }
  /// Find the active Panadapter
  ///
  /// - Returns:      a reference to a Panadapter (or nil)
  ///
  public class func findActive() -> Panadapter? {

    // find the Panadapters with an active Slice (if any)
    let panadapters = Api.sharedInstance.radio!.panadapters.values.filter { Slice.findActive(with: $0.id) != nil }
    guard panadapters.count >= 1 else { return nil }

    // return the first one
    return panadapters[0]
  }
  /// Find the Panadapter for a DaxIqChannel
  ///
  /// - Parameters:
  ///   - daxIqChannel:   a Dax channel number
  /// - Returns:          a Panadapter reference (or nil)
  ///
  public class func find(with channel: DaxIqChannel) -> Panadapter? {

    // find the Panadapters with the specified Channel (if any)
    let panadapters = Api.sharedInstance.radio!.panadapters.values.filter { $0.daxIqChannel == channel }
    guard panadapters.count >= 1 else { return nil }
    
    // return the first one
    return panadapters[0]
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a Panadapter
  ///
  /// - Parameters:
  ///   - streamId:           a Panadapter Stream Id
  ///   - queue:              Concurrent queue
  ///
  init(id: PanadapterId, queue: DispatchQueue) {
    
    self.id = id
    _q = queue

    // allocate two dataframes
    _dataframes.append(PanadapterFrame(frameSize: Panadapter.kMaxBins))
    _dataframes.append(PanadapterFrame(frameSize: Panadapter.kMaxBins))

    super.init()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Panadapter Reply Handler
  
  /// Process the Reply to an Rf Gain Info command, reply format: <value>,<value>,...<value>
  ///
  /// - Parameters:
  ///   - seqNum:         the Sequence Number of the original command
  ///   - responseValue:  the response value
  ///   - reply:          the reply
  ///
  func replyHandler(_ command: String, seqNum: String, responseValue: String, reply: String) {
    
    guard responseValue == Api.kNoError else {
      // Anything other than 0 is an error, log it and ignore the Reply
      os_log("%{public}@,  non-zero reply - %{public}@, %{public}@", log: _log, type: .default, command, responseValue, flexErrorString(errorCode: responseValue))
      
      return
    }
    // parse out the values
    let rfGainInfo = reply.valuesArray( delimiter: "," )
    _rfGainLow = rfGainInfo[0].iValue()
    _rfGainHigh = rfGainInfo[1].iValue()
    _rfGainStep = rfGainInfo[2].iValue()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by parseStatus(_:radio:queue:inUse:), executes on the parseQ
  
  /// Parse Panadapter key/value pairs
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // check for unknown keys
      guard let token = Token(rawValue: property.key) else {
        // unknown Key, log it and ignore the Key
        os_log("Unknown Panadapter token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .antList:
        willChangeValue(for: \.antList)
        _antList = property.value.components(separatedBy: ",")
        didChangeValue(for: \.antList)

      case .average:
        willChangeValue(for: \.average)
        _average = property.value.iValue()
        didChangeValue(for: \.average)

      case .band:
        willChangeValue(for: \.band)
        _band = property.value
        didChangeValue(for: \.band)

      case .bandwidth:
        willChangeValue(for: \.bandwidth)
        _bandwidth = property.value.mhzToHz()
        didChangeValue(for: \.bandwidth)

      case .bandZoomEnabled:
        willChangeValue(for: \.bandZoomEnabled)
        _bandZoomEnabled = property.value.bValue()
        didChangeValue(for: \.bandZoomEnabled)

      case .center:
        willChangeValue(for: \.center)
        _center = property.value.mhzToHz()
        didChangeValue(for: \.center)

      case .daxIqChannel:
        willChangeValue(for: \.daxIqChannel)
        _daxIqChannel = property.value.iValue()
        didChangeValue(for: \.daxIqChannel)

      case .fps:
        willChangeValue(for: \.fps)
        _fps = property.value.iValue()
        didChangeValue(for: \.fps)

      case .loopAEnabled:
        willChangeValue(for: \.loopAEnabled)
        _loopAEnabled = property.value.bValue()
        didChangeValue(for: \.loopAEnabled)

      case .loopBEnabled:
        willChangeValue(for: \.loopBEnabled)
        _loopBEnabled = property.value.bValue()
        didChangeValue(for: \.loopBEnabled)

      case .maxBw:
        willChangeValue(for: \.maxBw)
        _maxBw = property.value.mhzToHz()
        didChangeValue(for: \.maxBw)

      case .maxDbm:
        willChangeValue(for: \.maxDbm)
        _maxDbm = CGFloat(property.value.fValue())
        didChangeValue(for: \.maxDbm)

      case .minBw:
        willChangeValue(for: \.minBw)
        _minBw = property.value.mhzToHz()
        didChangeValue(for: \.minBw)

      case .minDbm:
        willChangeValue(for: \.minDbm)
        _minDbm = CGFloat(property.value.fValue())
        didChangeValue(for: \.minDbm)

      case .preamp:
        willChangeValue(for: \.preamp)
        _preamp = property.value
        didChangeValue(for: \.preamp)

      case .rfGain:
        willChangeValue(for: \.rfGain)
        _rfGain = property.value.iValue()
        didChangeValue(for: \.rfGain)

      case .rxAnt:
        willChangeValue(for: \.rxAnt)
        _rxAnt = property.value
        didChangeValue(for: \.rxAnt)

      case .segmentZoomEnabled:
        willChangeValue(for: \.segmentZoomEnabled)
        _segmentZoomEnabled = property.value.bValue()
        didChangeValue(for: \.segmentZoomEnabled)

      case .waterfallId:
         willChangeValue(for: \.waterfallId)
        _waterfallId = UInt32(property.value, radix: 16) ?? 0
        didChangeValue(for: \.waterfallId)

      case .wide:
        willChangeValue(for: \.wide)
        _wide = property.value.bValue()
        didChangeValue(for: \.wide)

      case .weightedAverageEnabled:
        willChangeValue(for: \.weightedAverageEnabled)
        _weightedAverageEnabled = property.value.bValue()
        didChangeValue(for: \.weightedAverageEnabled)

      case .wnbEnabled:
        willChangeValue(for: \.wnbEnabled)
        _wnbEnabled = property.value.bValue()
        didChangeValue(for: \.wnbEnabled)

      case .wnbLevel:
        willChangeValue(for: \.wnbLevel)
        _wnbLevel = property.value.iValue()
        didChangeValue(for: \.wnbLevel)

      case .wnbUpdating:
        willChangeValue(for: \.wnbUpdating)
        _wnbUpdating = property.value.bValue()
        didChangeValue(for: \.wnbUpdating)

      case .xPixels:
        willChangeValue(for: \.xPixels)
        _xPixels = CGFloat(property.value.fValue())
        didChangeValue(for: \.xPixels)

      case .xvtrLabel:
        willChangeValue(for: \.xvtrLabel)
        _xvtrLabel = property.value
        didChangeValue(for: \.xvtrLabel)

      case .yPixels:
        willChangeValue(for: \.yPixels)
        _yPixels = CGFloat(property.value.fValue())
        didChangeValue(for: \.yPixels)

      case .available, .capacity, .daxIqRate:
        // ignored by Panadapter
        break
        
      case .n1mmSpectrumEnable, .n1mmAddress, .n1mmPort, .n1mmRadio:
        // not sent in status messages
        break
      }
    }
    // is the Panadapter initialized?
    if !_initialized && center != 0 && bandwidth != 0 && (minDbm != 0.0 || maxDbm != 0.0) {
      
      // YES, the Radio (hardware) has acknowledged this Panadapter
      _initialized = true
      
      // notify all observers
      NC.post(.panadapterHasBeenAdded, object: self as Any?)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - VitaProcessor Protocol method
  
  //      called by Radio on the streamQ
  //
  //      The payload of the incoming Vita struct is converted to a PanadapterFrame and
  //      passed to the Panadapter Stream Handler
  
  /// Process the Panadapter Vita struct
  ///
  /// - Parameters:
  ///   - vita:        a Vita struct
  ///
  func vitaProcessor(_ vita: Vita) {
    
    
//    // If the frame index is out-of-sequence, ignore the packet
//    if _dataframes[_dataframeIndex].frameIndex < lastFrameIndex {
//      droppedPackets += 1
//      Log.sharedInstance.msg("Missing packet(s), frameIndex: \(_dataframes[_dataframeIndex].frameIndex) < last frameIndex: \(lastFrameIndex)", level: .warning, function: #function, file: #file, line: #line)
//      return
//    }
//    lastFrameIndex = _dataframes[_dataframeIndex].frameIndex
    
    // convert the Vita struct to a PanadapterFrame
    if _dataframes[_dataframeIndex].accumulate(vita: vita) {
      
      // Pass the data frame to this Panadapter's delegate
      delegate?.streamHandler(_dataframes[_dataframeIndex])

      // use the next dataframe
      _dataframeIndex = (_dataframeIndex + 1) % 2
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - PanadapterFrame class implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Panadapter vitaProcessor
//

public class PanadapterFrame {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var startingBinIndex  = 0                             // Index of first bin
  public private(set) var numberOfBins      = 0                             // Number of bins
  public private(set) var binSize           = 0                             // Bin size in bytes
  public private(set) var totalBinsInFrame  = 0                             // number of bins in the complete frame
  public private(set) var frameIndex        = 0                             // Frame index
  public var bins                           = [UInt16]()                    // Array of bin values
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private struct PayloadHeaderOld {                                        // struct to mimic payload layout
    var startingBinIndex                    : UInt32
    var numberOfBins                        : UInt32
    var binSize                             : UInt32
    var frameIndex                          : UInt32
  }
  private struct PayloadHeader {                                            // struct to mimic payload layout
    var startingBinIndex                    : UInt16
    var numberOfBins                        : UInt16
    var binSize                             : UInt16
    var totalBinsInFrame                    : UInt16
    var frameIndex                          : UInt32
  }

  private var _binsProcessed                = 0
  private var _byteOffsetToBins             = 0
  
  /// Initialize a PanadapterFrame
  ///
  /// - Parameter frameSize:    max number of Panadapter samples
  ///
  public init(frameSize: Int) {
    
    // allocate the bins array
    self.bins = [UInt16](repeating: 0, count: frameSize)
  }
  /// Accumulate Vita object(s) into a PanadapterFrame
  ///
  /// - Parameter vita:         incoming Vita object
  /// - Returns:                true if entire frame processed
  ///
  public func accumulate(vita: Vita) -> Bool {
  
    let payloadPtr = UnsafeRawPointer(vita.payloadData)
    
    if Api.sharedInstance.radioVersionMajor == 2 && Api.sharedInstance.radioVersionMinor >= 3 {
      // 2.3.x or greater
      // Bins are just beyond the payload
      _byteOffsetToBins = MemoryLayout<PayloadHeader>.size

      // map the payload to the New Payload struct
      let p = payloadPtr.bindMemory(to: PayloadHeader.self, capacity: 1)

      // byte swap and convert each payload component
      startingBinIndex = Int(CFSwapInt16BigToHost(p.pointee.startingBinIndex))
      numberOfBins = Int(CFSwapInt16BigToHost(p.pointee.numberOfBins))
      binSize = Int(CFSwapInt16BigToHost(p.pointee.binSize))
      totalBinsInFrame = Int(CFSwapInt16BigToHost(p.pointee.totalBinsInFrame))
      frameIndex = Int(CFSwapInt32BigToHost(p.pointee.frameIndex))
    
    } else {
      // pre 2.3.x
      // Bins are just beyond the payload
      _byteOffsetToBins = MemoryLayout<PayloadHeaderOld>.size

      // map the payload to the Old Payload struct
      let p = payloadPtr.bindMemory(to: PayloadHeaderOld.self, capacity: 1)
      
      // byte swap and convert each payload component
      startingBinIndex = Int(CFSwapInt32BigToHost(p.pointee.startingBinIndex))
      numberOfBins = Int(CFSwapInt32BigToHost(p.pointee.numberOfBins))
      binSize = Int(CFSwapInt32BigToHost(p.pointee.binSize))
      totalBinsInFrame = numberOfBins
      frameIndex = Int(CFSwapInt32BigToHost(p.pointee.frameIndex))
    }
    
    // update the count of bins processed
    _binsProcessed += numberOfBins
    
    // get a pointer to the Bins in the payload
    let binsPtr = payloadPtr.advanced(by: _byteOffsetToBins).bindMemory(to: UInt16.self, capacity: numberOfBins)
    
    // Swap the byte ordering of the data & place it in the bins
    for i in 0..<numberOfBins {
      bins[i+startingBinIndex] = CFSwapInt16BigToHost( binsPtr.advanced(by: i).pointee )
    }
    // reset the count if the entire frame has been accumulated
    if _binsProcessed == totalBinsInFrame { _binsProcessed = 0 }
    
    // return true if the entire frame has been accumulated
    return _binsProcessed == 0
  }
}

// --------------------------------------------------------------------------------
// MARK: - Panadapter Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Panadapter tokens
// --------------------------------------------------------------------------------

extension Panadapter {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  internal var _antList: [String] {
    get { return _q.sync { __antList } }
    set { _q.sync(flags: .barrier) { __antList = newValue } } }
  
  internal var _average: Int {
    get { return _q.sync { __average } }
    set { _q.sync(flags: .barrier) { __average = newValue } } }
  
  internal var _band: String {
    get { return _q.sync { __band } }
    set { _q.sync(flags: .barrier) { __band = newValue } } }
  
  internal var _bandwidth: Int {
    get { return _q.sync { __bandwidth } }
    set { _q.sync(flags: .barrier) { __bandwidth = newValue } } }
  
  internal var _bandZoomEnabled: Bool {
    get { return _q.sync { __bandZoomEnabled } }
    set { _q.sync(flags: .barrier) { __bandZoomEnabled = newValue } } }
  
  internal var _center: Int {
    get { return _q.sync { __center } }
    set { _q.sync(flags: .barrier) { __center = newValue } } }
  
  internal var _daxIqChannel: Int {
    get { return _q.sync { __daxIqChannel } }
    set { _q.sync(flags: .barrier) { __daxIqChannel = newValue } } }
  
  internal var _fps: Int {
    get { return _q.sync { __fps } }
    set { _q.sync(flags: .barrier) { __fps = newValue } } }
  
  internal var _loggerDisplayEnabled: Bool {
    get { return _q.sync { __loggerDisplayEnabled } }
    set { _q.sync(flags: .barrier) { __loggerDisplayEnabled = newValue } } }
  
  internal var _loggerDisplayIpAddress: String {
    get { return _q.sync { __loggerDisplayIpAddress } }
    set { _q.sync(flags: .barrier) { __loggerDisplayIpAddress = newValue } } }
  
  internal var _loggerDisplayPort: Int {
    get { return _q.sync { __loggerDisplayPort } }
    set { _q.sync(flags: .barrier) { __loggerDisplayPort = newValue } } }
  
  internal var _loggerDisplayRadioNumber: Int {
    get { return _q.sync { __loggerDisplayRadioNumber } }
    set { _q.sync(flags: .barrier) { __loggerDisplayRadioNumber = newValue } } }
  
  internal var _loopAEnabled: Bool {
    get { return _q.sync { __loopAEnabled } }
    set { _q.sync(flags: .barrier) { __loopAEnabled = newValue } } }
  
  internal var _loopBEnabled: Bool {
    get { return _q.sync { __loopBEnabled } }
    set { _q.sync(flags: .barrier) { __loopBEnabled = newValue } } }
  
  internal var _maxBw: Int {
    get { return _q.sync { __maxBw } }
    set { _q.sync(flags: .barrier) { __maxBw = newValue } } }
  
  internal var _maxDbm: CGFloat {
    get { return _q.sync { __maxDbm } }
    set { _q.sync(flags: .barrier) { __maxDbm = newValue } } }
  
  internal var _minBw: Int {
    get { return _q.sync { __minBw } }
    set { _q.sync(flags: .barrier) { __minBw = newValue } } }
  
  internal var _minDbm: CGFloat {
    get { return _q.sync { __minDbm } }
    set { _q.sync(flags: .barrier) { __minDbm = newValue } } }
  
  internal var _preamp: String {
    get { return _q.sync { __preamp } }
    set { _q.sync(flags: .barrier) { __preamp = newValue } } }
  
  internal var _rfGain: Int {
    get { return _q.sync { __rfGain } }
    set { _q.sync(flags: .barrier) { __rfGain = newValue } } }
  
  internal var _rfGainHigh: Int {
    get { return _q.sync { __rfGainHigh } }
    set { _q.sync(flags: .barrier) { __rfGainHigh = newValue } } }
  
  internal var _rfGainLow: Int {
    get { return _q.sync { __rfGainLow } }
    set { _q.sync(flags: .barrier) { __rfGainLow = newValue } } }
  
  internal var _rfGainStep: Int {
    get { return _q.sync { __rfGainStep } }
    set { _q.sync(flags: .barrier) { __rfGainStep = newValue } } }
  
  internal var _rfGainValues: String {
    get { return _q.sync { __rfGainValues } }
    set { _q.sync(flags: .barrier) { __rfGainValues = newValue } } }
  
  internal var _rxAnt: String {
    get { return _q.sync { __rxAnt } }
    set { _q.sync(flags: .barrier) { __rxAnt = newValue } } }
  
  internal var _segmentZoomEnabled: Bool {
    get { return _q.sync { __segmentZoomEnabled } }
    set { _q.sync(flags: .barrier) { __segmentZoomEnabled = newValue } } }
  
  internal var _waterfallId: WaterfallId {
    get { return _q.sync { __waterfallId } }
    set { _q.sync(flags: .barrier) { __waterfallId = newValue } } }
  
  internal var _weightedAverageEnabled: Bool {
    get { return _q.sync { __weightedAverageEnabled } }
    set { _q.sync(flags: .barrier) { __weightedAverageEnabled = newValue } } }
  
  internal var _wide: Bool {
    get { return _q.sync { __wide } }
    set { _q.sync(flags: .barrier) { __wide = newValue } } }
  
  internal var _wnbEnabled: Bool {
    get { return _q.sync { __wnbEnabled } }
    set { _q.sync(flags: .barrier) { __wnbEnabled = newValue } } }
  
  internal var _wnbLevel: Int {
    get { return _q.sync { __wnbLevel } }
    set { _q.sync(flags: .barrier) { __wnbLevel = newValue } } }
  
  internal var _wnbUpdating: Bool {
    get { return _q.sync { __wnbUpdating } }
    set { _q.sync(flags: .barrier) { __wnbUpdating = newValue } } }
  
  internal var _xPixels: CGFloat {
    get { return _q.sync { __xPixels } }
    set { _q.sync(flags: .barrier) { __xPixels = newValue } } }
  
  internal var _xvtrLabel: String {
    get { return _q.sync { __xvtrLabel } }
    set { _q.sync(flags: .barrier) { __xvtrLabel = newValue } } }
  
  internal var _yPixels: CGFloat {
    get { return _q.sync { __yPixels } }
    set { _q.sync(flags: .barrier) { __yPixels = newValue } } }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // FIXME: Should any of these send a message to the Radio?
  //          If yes, implement it, if not should they be "get" only?
  
  // listed in alphabetical order
  @objc dynamic public var antList: [String] {
    return _antList }
  
  @objc dynamic public var maxBw: Int {
    return _maxBw }
  
  @objc dynamic public var minBw: Int {
    return _minBw }
  
  @objc dynamic public var preamp: String {
    return _preamp }
  
  @objc dynamic public var rfGainHigh: Int {
    return _rfGainHigh }
  
  @objc dynamic public var rfGainLow: Int {
    return _rfGainLow }
  
  @objc dynamic public var rfGainStep: Int {
    return _rfGainStep }
  
  @objc dynamic public var rfGainValues: String {
    return _rfGainValues }
  
  @objc dynamic public var waterfallId: UInt32 {
    return _waterfallId }
  
  @objc dynamic public var wide: Bool {
    return _wide }
  
  @objc dynamic public var wnbUpdating: Bool {
    return _wnbUpdating }
  
  @objc dynamic public var xvtrLabel: String {
    return _xvtrLabel }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
  
  public var delegate: StreamHandler? {
    get { return _q.sync { _delegate } }
    set { _q.sync(flags: .barrier) { _delegate = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Panadapter tokens
  
  internal enum Token : String {
    // on Panadapter
    case antList                    = "ant_list"
    case average
    case band
    case bandwidth
    case bandZoomEnabled            = "band_zoom"
    case center
    case daxIqChannel               = "daxiq"
    case fps
    case loopAEnabled               = "loopa"
    case loopBEnabled               = "loopb"
    case maxBw                      = "max_bw"
    case maxDbm                     = "max_dbm"
    case minBw                      = "min_bw"
    case minDbm                     = "min_dbm"
    case preamp                     = "pre"
    case rfGain                     = "rfgain"
    case rxAnt                      = "rxant"
    case segmentZoomEnabled         = "segment_zoom"
    case waterfallId                = "waterfall"
    case weightedAverageEnabled     = "weighted_average"
    case wide
    case wnbEnabled                 = "wnb"
    case wnbLevel                   = "wnb_level"
    case wnbUpdating                = "wnb_updating"
    case xPixels                    = "x_pixels"
    case xvtrLabel                  = "xvtr"
    case yPixels                    = "y_pixels"
    // ignored by Panadapter
    case available
    case capacity
    case daxIqRate                  = "daxiq_rate"
    // not sent in status messages
    case n1mmSpectrumEnable         = "n1mm_spectrum_enable"
    case n1mmAddress                = "n1mm_address"
    case n1mmPort                   = "n1mm_port"
    case n1mmRadio                  = "n1mm_radio"
  }
}
