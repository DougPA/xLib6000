//
//  Cwx.swift
//  xLib6000
//
//  Created by Douglas Adams on 6/30/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Cwx Class implementation
//
//      creates a Cwx instance to be used by a Client to support the
//      rendering of a Cwx. Cwx objects are added, removed and updated 
//      by the incoming TCP messages.
//
// --------------------------------------------------------------------------------

public final class Cwx                      : NSObject, PropertiesParser {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var messageQueuedEventHandler      : ((_ sequence: Int, _ bufferIndex: Int) -> Void)?
  public var charSentEventHandler           : ((_ index: Int) -> Void)?
  public var eraseSentEventHandler          : ((_ start: Int, _ stop: Int) -> Void)?
  
  // ------------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var macros                       : [String]
  internal let kMinDelayMs                  = 0                             // Min delay (ms)
  internal let kMaxDelayMs                  = 2000                          // Max delay (ms)
  internal let kMinSpeed                    = 5                             // Min speed (wpm)
  internal let kMaxSpeed                    = 100                           // Max speed (wpm)
  internal let kMaxNumberOfMacros           = 12                            // Max number of macros
    
  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _q                            : DispatchQueue                 // Q for object synchronization
  
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  //
  private var __breakInDelay                = 0                             // BreakIn delay
  private var __qskEnabled                  = false                         // QSK Enabled
  private var __wpm                         = 0                             // Speed (wpm)
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize Cwx
  ///
  /// - Parameters:
  ///   - radio:              parent Radio class
  ///   - queue:              Concurrent queue
  ///
  init(queue: DispatchQueue) {
    
    self._q = queue
    macros = [String](repeating: "", count: kMaxNumberOfMacros)
    
    super.init()
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Get the specified Cwx Macro
  ///
  ///     NOTE:
  ///         Macros are numbered 0..<kMaxNumberOfMacros internally
  ///         Macros are numbered 1...kMaxNumberOfMacros in commands
  ///
  /// - Parameters:
  ///   - index:              the index of the macro
  ///   - macro:              on return, contains the text of the macro
  /// - Returns:              true if found, false otherwise
  ///
  public func getMacro(index: Int, macro: inout String) -> Bool {
    
    if index < 0 || index > kMaxNumberOfMacros - 1 { return false }
    
    macro = macros[index]
    
    return true
  }
  
  // --------------------------------------------------------------------------------
  // MARK: - Cwx Reply Handler
  
  /// Process a Cwx command reply
  ///
  /// - Parameters:
  ///   - command:        the original command
  ///   - seqNum:         the Sequence Number of the original command
  ///   - responseValue:  the response value
  ///   - reply:          the reply
  ///
  func replyHandler(_ command: String, seqNum: String, responseValue: String, reply: String) {
    
    // if a block was specified for the "cwx send" command the response is "charPos,block"
    // if no block was given the response is "charPos"
    let values = reply.components(separatedBy: ",")
    
    let components = values.count
    
    // zero or anything greater than 2 is an error, log it and ignore the Reply
    guard components == 1 || components == 2 else {
      
      Log.sharedInstance.msg(command + ", Invalid reply", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    // get the character position
    let charPos = Int(values[0])
    
    // not an integer, log it and ignore the Reply
    guard charPos != nil else {
      
      Log.sharedInstance.msg(command + ", Invalid character position", level: .warning, function: #function, file: #file, line: #line)
      return
    }
    
    if components == 1 {
      
      // 1 component - no block number
      
      // inform the Event Handler (if any), use 0 as a block identifier
      messageQueuedEventHandler?(charPos!, 0)
      
    } else {
      
      // 2 components - get the block number
      let block = Int(values[1])
      
      // not an integer, log it and ignore the Reply
      guard block != nil else {
        
        Log.sharedInstance.msg(command + ", Invalid block", level: .warning, function: #function, file: #file, line: #line)
        return
      }
      // inform the Event Handler (if any)
      messageQueuedEventHandler?(charPos!, block!)
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - PropertiesParser Protocol method
  //     called by Radio.parseStatusMessage(_:), executes on the parseQ

  /// Parse Cwx key/value pairs, called by Radio, executes on the radioQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray)  {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // is it a Macro?
      if property.key.hasPrefix("macro") && property.key.lengthOfBytes(using: String.Encoding.ascii) > 5 {
        
        // YES, get the index
        let oIndex = property.key.index(of: "o")!
        let numberIndex = property.key.index(after: oIndex)
        let index = Int( property.key[numberIndex...] ) ?? 0
        
        // ignore invalid indexes
        if index < 1 || index > kMaxNumberOfMacros { continue }
        
        // update the macro after "unFixing" the string
        macros[index - 1] = property.value.unfix()
        
      } else {
        
        // Check for Unknown token
        guard let token = Token(rawValue: property.key) else {
          
          // unknown token, log it and ignore the token
          Log.sharedInstance.msg("Unknown token - \(property.key)", level: .debug, function: #function, file: #file, line: #line)
          continue
        }
        // Known tokens, in alphabetical order
        switch token {
          
        case .breakInDelay:
          willChangeValue(forKey: "breakInDelay")
          _breakInDelay = property.value.iValue()
          didChangeValue(forKey: "breakInDelay")
          
        case .erase:
          let values = property.value.components(separatedBy: ",")
          if values.count != 2 { break }
          let start = Int(values[0])
          let stop = Int(values[1])
          if let start = start, let stop = stop {
            // inform the Event Handler (if any)
            eraseSentEventHandler?(start, stop)
          }
          
        case .qskEnabled:
          willChangeValue(forKey: "qskEnabled")
          _qskEnabled = property.value.bValue()
          didChangeValue(forKey: "qskEnabled")
          
        case .sent:
          // inform the Event Handler (if any)
          charSentEventHandler?(property.value.iValue())
          
        case .wpm:
          willChangeValue(forKey: "wpm")
          _wpm = property.value.iValue()
          didChangeValue(forKey: "wpm")
        }
      }
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Cwx Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Cwx tokens
// --------------------------------------------------------------------------------

extension Cwx {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  internal var _breakInDelay: Int {
    get { return _q.sync { __breakInDelay } }
    set { _q.sync(flags: .barrier) { __breakInDelay = newValue } } }
  
  internal var _qskEnabled: Bool {
    get { return _q.sync { __qskEnabled } }
    set { _q.sync(flags: .barrier) { __qskEnabled = newValue } } }
  
  internal var _wpm: Int {
    get { return _q.sync { __wpm } }
    set { _q.sync(flags: .barrier) { __wpm = newValue } } }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  // ----- None -----
  
  // ----------------------------------------------------------------------------
  // Mark: - Cwx tokens
  
  internal enum Token : String {
    case breakInDelay = "break_in_delay"
    case qskEnabled = "qsk_enabled"
    case erase
    case sent
    case wpm = "wpm"
  }
  
}
