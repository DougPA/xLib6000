//
//  Protocols.swift
//  xLib6000
//
//  Created by Douglas Adams on 5/20/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Protocols

public protocol ApiDelegate {
  
  /// A message has been sent to the Radio (hardware)
  ///
  /// - Parameter text:           the text of the message
  ///
  func sentMessage(_ text: String)
  
  /// A message has been received from the Radio (hardware)
  ///
  /// - Parameter text:           the text of the message
  func receivedMessage(_ text: String)
  
  /// A command sent to the Radio (hardware) needs to register a Reply Handler
  ///
  /// - Parameters:
  ///   - sequenceId:             the sequence number of the Command
  ///   - replyTuple:             a Reply Tuple
  ///
  func addReplyHandler(_ sequenceId: SequenceId, replyTuple: ReplyTuple)
  
  /// The default Reply Handler (to process replies to Commands sent to the Radio hardware)
  ///
  /// - Parameters:
  ///   - command:                a Command string
  ///   - seqNum:                 the Command's sequence number
  ///   - responseValue:          the response contined in the Reply to the Command
  ///   - reply:                  the descriptive text contained in the Reply to the Command
  ///
  func defaultReplyHandler(_ command: String, seqNum: String, responseValue: String, reply: String)
  
  /// Process received UDP Vita packets
  ///
  /// - Parameter vitaPacket:     a Vita packet
  ///
  func vitaParser(_ vitaPacket: Vita)
}

protocol StaticModel                        : class {
  
  //  Static Model objects are created / destroyed in the Radio class.
  //  Static Model object properties are set in the instance's parseProperties method.
  
  /// Parse <key=value> arrays to set object properties
  ///
  /// - Parameter keyValues:    a KeyValues array containing object property values
  ///
  func parseProperties(_ keyValues: KeyValuesArray)
}

protocol DynamicModel                       : StaticModel {
  
  //  Dynamic Model objects are created / destroyed in the Model's parseStatus static method.
  //  Dynamic Model object properties are set in the instance's parseProperties method.
  
  /// Parse <key=value> arrays to determine object status
  ///
  /// - Parameters:
  ///   - keyValues:            a KeyValues array containing a Status message for an object type
  ///   - radio:                the current Radio object
  ///   - queue:                the GCD queue associated with the object type in the status message
  ///   - inUse:                a flag indicating whether the object in the status message is active
  ///
  static func parseStatus(_ keyValues: KeyValuesArray, radio: Radio, queue: DispatchQueue, inUse: Bool)
}

protocol DynamicModelWithStream             : DynamicModel {
  
  // Some Dynamic Models have associated with them a UDP data stream & must
  // provide a method to process the Vita packets from the UDP stream
  
  /// Process vita packets
  ///
  /// - Parameter vitaPacket:       a Vita packet
  ///
  func vitaProcessor(_ vitaPacket: Vita)
}

public protocol StreamHandler               : class {
  
  /// Process a frame of Stream data
  ///
  /// - Parameter streamFrame:              a frame of data
  ///
  func streamHandler<T>(_ streamFrame: T)
}

