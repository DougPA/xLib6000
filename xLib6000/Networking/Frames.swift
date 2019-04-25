//
//  Frames.swift
//  xLib6000
//
//  Created by Douglas Adams on 2/20/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Foundation

/// Class containing Panadapter Stream data
///
///   populated by the Panadapter vitaHandler
///
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
  private var _expectedIndex                = 0
  private var _binsProcessed                = 0
  private var _byteOffsetToBins             = 0
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a PanadapterFrame
  ///
  /// - Parameter frameSize:    max number of Panadapter samples
  ///
  public init(frameSize: Int) {
    
    // allocate the bins array
    self.bins = [UInt16](repeating: 0, count: frameSize)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Instance methods
  
  /// Accumulate Vita object(s) into a PanadapterFrame
  ///
  /// - Parameter vita:         incoming Vita object
  /// - Returns:                true if entire frame processed
  ///
  public func accumulate(vita: Vita, expectedIndex: inout Int) -> Bool {
    
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
    // is this the first frame?
    if expectedIndex == -1 { expectedIndex = frameIndex }
    
    if frameIndex < expectedIndex {
      // log it
//      os_log("Out of sequence Frame ignored: expected = %{public}d, received = %{public}d", log: _log, type: .default, expectedIndex, frameIndex)
      Api.sharedInstance.log.msg("Out of sequence Frame ignored: expected = \(expectedIndex), received = \(frameIndex)", level: .warning, function: #function, file: #file, line: #line)
      return false
    }
    
    if frameIndex > expectedIndex {
      // log it
//      os_log("%{public}d Frame(s) skipped: expected = %{public}d, received = %{public}d", log: _log, type: .default, frameIndex - expectedIndex, expectedIndex, frameIndex)
      Api.sharedInstance.log.msg("\(frameIndex - expectedIndex) Frame(s) skipped: expected = \(expectedIndex), received = \(frameIndex)", level: .warning, function: #function, file: #file, line: #line)
      // restart bin processing
      _binsProcessed = 0
      expectedIndex = frameIndex
    }
    
    if frameIndex == expectedIndex {
      
      // get a pointer to the Bins in the payload
      let binsPtr = payloadPtr.advanced(by: _byteOffsetToBins).bindMemory(to: UInt16.self, capacity: numberOfBins)
      
      // Swap the byte ordering of the data & place it in the bins
      for i in 0..<numberOfBins {
        bins[i+startingBinIndex] = CFSwapInt16BigToHost( binsPtr.advanced(by: i).pointee )
      }
      // update the count of bins processed
      _binsProcessed += numberOfBins
      
      // reset the count if the entire frame has been accumulated
      if _binsProcessed == totalBinsInFrame { _binsProcessed = 0 ; expectedIndex += 1}
    }
    // return true if the entire frame has been accumulated
    return _binsProcessed == 0
  }
}

/// Class containing Waterfall Stream data
///
///   populated by the Waterfall vitaHandler
///
public class WaterfallFrame {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var firstBinFreq      : CGFloat   = 0.0               // Frequency of first Bin (Hz)
  public private(set) var binBandwidth      : CGFloat   = 0.0               // Bandwidth of a single bin (Hz)
  public private(set) var lineDuration      = 0                             // Duration of this line (ms)
  public private(set) var numberOfBins      = 0                             // Number of bins
  public private(set) var height            = 0                             // Height of frame (pixels)
  public private(set) var timeCode          = 0                             // Time code
  public private(set) var autoBlackLevel    : UInt32 = 0                    // Auto black level
  public private(set) var totalBinsInFrame  = 0                             //
  public private(set) var startingBinIndex  = 0                             //
  public var bins                           = [UInt16]()                    // Array of bin values
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _binsProcessed                = 0
  private var _byteOffsetToBins             = 0
  
  private struct PayloadHeaderOld {                                         // struct to mimic payload layout
    var firstBinFreq                        : UInt64                        // 8 bytes
    var binBandwidth                        : UInt64                        // 8 bytes
    var lineDuration                        : UInt32                        // 4 bytes
    var numberOfBins                        : UInt16                        // 2 bytes
    var lineHeight                          : UInt16                        // 2 bytes
    var timeCode                            : UInt32                        // 4 bytes
    var autoBlackLevel                      : UInt32                        // 4 bytes
  }
  
  private struct PayloadHeader {                                            // struct to mimic payload layout
    var firstBinFreq                        : UInt64                        // 8 bytes
    var binBandwidth                        : UInt64                        // 8 bytes
    var lineDuration                        : UInt32                        // 4 bytes
    var numberOfBins                        : UInt16                        // 2 bytes
    var height                              : UInt16                        // 2 bytes
    var timeCode                            : UInt32                        // 4 bytes
    var autoBlackLevel                      : UInt32                        // 4 bytes
    var totalBinsInFrame                    : UInt16                        // 2 bytes
    var firstBinIndex                       : UInt16                        // 2 bytes
  }
  
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Instance methods
  
  /// Accumulate Vita object(s) into a WaterfallFrame
  ///
  /// - Parameter vita:         incoming Vita object
  /// - Returns:                true if entire frame processed
  ///
  public func accumulate(vita: Vita, expectedIndex: inout Int) -> Bool {
    
    let payloadPtr = UnsafeRawPointer(vita.payloadData)
    
    if Api.sharedInstance.radioVersionMajor == 2 && Api.sharedInstance.radioVersionMinor >= 3 {
      // 2.3.x or greater
      // map the payload to the New Payload struct
      let p = payloadPtr.bindMemory(to: PayloadHeader.self, capacity: 1)
      
      // 2.3.x or greater
      // Bins are just beyond the payload
      _byteOffsetToBins = MemoryLayout<PayloadHeader>.size
      
      // byte swap and convert each payload component
      firstBinFreq = CGFloat(CFSwapInt64BigToHost(p.pointee.firstBinFreq)) / 1.048576E6
      binBandwidth = CGFloat(CFSwapInt64BigToHost(p.pointee.binBandwidth)) / 1.048576E6
      lineDuration = Int( CFSwapInt32BigToHost(p.pointee.lineDuration) )
      numberOfBins = Int( CFSwapInt16BigToHost(p.pointee.numberOfBins) )
      height = Int( CFSwapInt16BigToHost(p.pointee.height) )
      timeCode = Int( CFSwapInt32BigToHost(p.pointee.timeCode) )
      autoBlackLevel = CFSwapInt32BigToHost(p.pointee.autoBlackLevel)
      totalBinsInFrame = Int( CFSwapInt16BigToHost(p.pointee.totalBinsInFrame) )
      startingBinIndex = Int( CFSwapInt16BigToHost(p.pointee.firstBinIndex) )
      
    } else {
      // pre 2.3.x
      // map the payload to the Old Payload struct
      let p = payloadPtr.bindMemory(to: PayloadHeaderOld.self, capacity: 1)
      
      // pre 2.3.x
      // Bins are just beyond the payload
      _byteOffsetToBins = MemoryLayout<PayloadHeaderOld>.size
      
      // byte swap and convert each payload component
      firstBinFreq = CGFloat(CFSwapInt64BigToHost(p.pointee.firstBinFreq)) / 1.048576E6
      binBandwidth = CGFloat(CFSwapInt64BigToHost(p.pointee.binBandwidth)) / 1.048576E6
      lineDuration = Int( CFSwapInt32BigToHost(p.pointee.lineDuration) )
      numberOfBins = Int( CFSwapInt16BigToHost(p.pointee.numberOfBins) )
      height = Int( CFSwapInt16BigToHost(p.pointee.lineHeight) )
      timeCode = Int( CFSwapInt32BigToHost(p.pointee.timeCode) )
      autoBlackLevel = CFSwapInt32BigToHost(p.pointee.autoBlackLevel)
      totalBinsInFrame = numberOfBins
      startingBinIndex = 0
    }
    // is this the first frame?
    if expectedIndex == -1 { expectedIndex = timeCode }
    
    if timeCode < expectedIndex {
      // log it
//      os_log("Out of sequence Frame ignored: expected = %{public}d, received = %{public}d", log: _log, type: .default, expectedIndex, timeCode)
      Api.sharedInstance.log.msg("Out of sequence Frame ignored: expected = \(expectedIndex), received = \(timeCode)", level: .warning, function: #function, file: #file, line: #line)
      return false
    }
    
    if timeCode > expectedIndex {
      // log it
//      os_log("%{public}d Frame(s) skipped: expected = %{public}d, received = %{public}d", log: _log, type: .default, timeCode - expectedIndex, expectedIndex, timeCode)
      Api.sharedInstance.log.msg("\(timeCode - expectedIndex) Frame(s) skipped: expected = \(expectedIndex), received = \(timeCode)", level: .warning, function: #function, file: #file, line: #line)
      // restart bin processing
      _binsProcessed = 0
      expectedIndex = timeCode
    }
    
    if timeCode == expectedIndex {
      
      // get a pointer to the Bins in the payload
      let binsPtr = payloadPtr.advanced(by: _byteOffsetToBins).bindMemory(to: UInt16.self, capacity: numberOfBins)
      
      // Swap the byte ordering of the data & place it in the bins
      for i in 0..<numberOfBins {
        bins[i+startingBinIndex] = CFSwapInt16BigToHost( binsPtr.advanced(by: i).pointee )
      }
      // update the count of bins processed
      _binsProcessed += numberOfBins
      
      // reset the count if the entire frame has been accumulated
      if _binsProcessed == totalBinsInFrame { _binsProcessed = 0 }
    }
    
    // return true if the entire frame has been accumulated
    return _binsProcessed == 0
  }
}

/// Struct containing Audio Stream data
///
///   populated by the Audio Stream vitaHandler
///
public struct AudioStreamFrame {
  
  public var daxChannel                     = -1
  public private(set) var samples           = 0                             // number of samples (L/R) in this frame
  public var leftAudio                      = [Float]()                     // Array of left audio samples
  public var rightAudio                     = [Float]()                     // Array of right audio samples
  
  /// Initialize an AudioStreamFrame
  ///
  /// - Parameters:
  ///   - payload:        pointer to a Vita packet payload
  ///   - numberOfBytes:  number of bytes in the payload
  ///
  public init(payload: UnsafeRawPointer, numberOfBytes: Int) {
    
    // 4 byte each for left and right sample (4 * 2)
    self.samples = numberOfBytes / (4 * 2)
    
    // allocate the samples arrays
    self.leftAudio = [Float](repeating: 0, count: samples)
    self.rightAudio = [Float](repeating: 0, count: samples)
  }
}

/// Struct containing IQ Stream data
///
///   populated by the IQ Stream vitaHandler
///
public struct IqStreamFrame {
  
  public var daxIqChannel                   = -1
  public private(set) var samples           = 0                             // number of samples (L/R) in this frame
  public var realSamples                    = [Float]()                     // Array of real (I) samples
  public var imagSamples                    = [Float]()                     // Array of imag (Q) samples
  
  /// Initialize an IqtreamFrame
  ///
  /// - Parameters:
  ///   - payload:        pointer to a Vita packet payload
  ///   - numberOfBytes:  number of bytes in the payload
  ///
  public init(payload: UnsafeRawPointer, numberOfBytes: Int) {
    
    // 4 byte each for left and right sample (4 * 2)
    self.samples = numberOfBytes / (4 * 2)
    
    // allocate the samples arrays
    self.realSamples = [Float](repeating: 0, count: samples)
    self.imagSamples = [Float](repeating: 0, count: samples)
  }
}

/// Struct containing Mic Audio Stream data
///
public struct MicAudioStreamFrame {
  
  public private(set) var samples           = 0                             // number of samples (L/R) in this frame
  public var leftAudio                      = [Float]()                     // Array of left audio samples
  public var rightAudio                     = [Float]()                     // Array of right audio samples
  
  /// Initialize a AudioStreamFrame
  ///
  /// - Parameters:
  ///   - payload:        pointer to a Vita packet payload
  ///   - numberOfWords:  number of 32-bit Words in the payload
  ///
  public init(payload: UnsafeRawPointer, numberOfBytes: Int) {
    
    // 4 byte each for left and right sample (4 * 2)
    self.samples = numberOfBytes / (4 * 2)
    
    // allocate the samples arrays
    self.leftAudio = [Float](repeating: 0, count: samples)
    self.rightAudio = [Float](repeating: 0, count: samples)
  }
}

/// Struct containing Opus Stream data
///
public struct OpusFrame {
  
  public var samples: [UInt8]                     // array of samples
  public var numberOfSamples: Int                 // number of samples
  
  /*
   public var duration: Float                     // frame duration (ms)
   public var channels: Int                       // number of channels (1 or 2)
   */
  
  /// Initialize an OpusFrame
  ///
  /// - Parameters:
  ///   - payload:            pointer to the Vita packet payload
  ///   - numberOfSamples:    number of Samples in the payload
  ///
  public init(payload: UnsafeRawPointer, numberOfSamples: Int) {
    
    // allocate the samples array
    samples = [UInt8](repeating: 0, count: numberOfSamples)
    
    // save the count and copy the data
    self.numberOfSamples = numberOfSamples
    memcpy(&samples, payload, numberOfSamples)
    
    /*
     // MARK: This code unneeded at this time
     
     // Flex 6000 series uses:
     //     duration = 10 ms
     //     channels = 2 (stereo)
     
     // determine the frame duration
     let durationCode = (samples[0] & 0xF8)
     switch durationCode {
     case 0xC0:
     duration = 2.5
     case 0xC8:
     duration = 5.0
     case 0xD0:
     duration = 10.0
     case 0xD8:
     duration = 20.0
     default:
     duration = 0
     }
     // determine the number of channels (mono = 1, stereo = 2)
     channels = (samples[0] & 0x04) == 0x04 ? 2 : 1
     */
  }
}

