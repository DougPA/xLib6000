//
//  Notifications.swift
//  CommonCode
//
//  Created by Douglas Adams on 1/4/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Notifications

public typealias NC = NotificationCenter

//
// Defined NotificationTypes
//      in alphabetical order
//
public enum NotificationType : String {
  
  case amplifierHasBeenAdded
  case amplifierWillBeRemoved
  
  case audioStreamHasBeenAdded
  case audioStreamWillBeRemoved
  
  case clientDidConnect
  case clientDidDisconnect
  
  case equalizerHasBeenAdded
  
  case globalProfileChanged
  case globalProfileCreated
  case globalProfileRemoved
  case globalProfileUpdated
  
  case guiConnectionEstablished
  
  case iqStreamHasBeenAdded
  case iqStreamWillBeRemoved
  
  case memoryHasBeenAdded
  case memoryWillBeRemoved
  
  case meterHasBeenAdded
  case meterWillBeRemoved
  case meterUpdated
  
  case micAudioStreamHasBeenAdded
  case micAudioStreamWillBeRemoved
  
  case opusRxHasBeenAdded
  case opusRxWillBeRemoved

  case opusTxHasBeenAdded
  case opusTxWillBeRemoved

  case panadapterHasBeenAdded
  case panadapterWillBeRemoved
  
  case profileHasBeenAdded
  case profileWillBeRemoved
  
  case radioHasBeenAdded
  case radioWillBeRemoved
  case radioHasBeenRemoved
  
  case radiosAvailable                      // Radios have appeared / disappeared
  
  case sliceBecameActive
  case sliceHasBeenAdded
  case sliceWillBeRemoved
  
  case sliceMeterHasBeenAdded
  case sliceMeterWillBeRemoved

  case tcpDidConnect
  case tcpDidDisconnect
  case tcpPingStarted
  case tcpPingFirstResponse                 // the first ping reponse was received
  case tcpPingTimeout
  case tcpWillDisconnect
  
  case tnfHasBeenAdded
  case tnfWillBeRemoved
  
  case transmitHasBeenAdded

  case txAudioStreamHasBeenAdded
  case txAudioStreamWillBeRemoved
  
  case udpDidBind
  
  case usbCableHasBeenAdded
  case usbCableWillBeRemoved
  
  case waterfallHasBeenAdded
  case waterfallWillBeRemoved
  
  case updateRequired                       // API and Radio versions incompatible
  
  case xvtrHasBeenAdded
  case xvtrWillBeRemoved
}

