//
//  RadioCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/14/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Radio Class extensions
//              - Public methods for sending data to the Radio
//              - Public enum for Primary, Secondary & Subscription Command lists
//              - Public methods that send commands to the Radio
//              - Dynamic public properties that send commands to the Radio
// --------------------------------------------------------------------------------

extension Radio {
  
  static let kApfCmd                        = "eq apf "                     // Text of command messages
  static let kCmd                           = "radio "
  static let kSetCmd                        = "radio set "
  static let kMixerCmd                      = "mixer "
  static let kUptimeCmd                     = "radio uptime"
  static let kStreamCreateCmd               = "stream create "
  static let kStreamRemoveCmd               = "stream remove "
  static let kGpsCmd                        = "radio gps "
  static let kLicenseCmd                    = "license "
  static let kMicStreamCreateCmd            = "stream create daxmic"
  static let kXmitCmd                       = "xmit "
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send commands to the Radio (hardware)
  
  // listed in alphabetical order
  
  // MARK: --- Amplifier ---
  
  /// Create an Amplifier record
  ///
  /// - Parameters:
  ///   - ip:             Ip Address (dotted-decimal STring)
  ///   - port:           Port number
  ///   - model:          Model
  ///   - serialNumber:   Serial number
  ///   - antennaPairs:   antenna pairs
  ///   - callback:       ReplyHandler (optional)
  ///
  public func amplifierCreate(ip: String, port: Int, model: String, serialNumber: String, antennaPairs: String, callback: ReplyHandler? = nil) {
    
    // TODO: add code
  }
  
  /// Remove an Amplifier record
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func amplifierRemove(callback: ReplyHandler? = nil) {
    
    // TODO: add code
  }
  
  /// Change the Amplifier Mode
  ///
  /// - Parameters:
  ///   - mode:           mode (String)
  ///   - callback:       ReplyHandler (optional)
  ///
  public func amplifierMode(_ mode: Bool, callback: ReplyHandler? = nil) {
    
    // TODO: add code
  }
  
  // MARK: --- Antenna List ---
  
  /// Request a list of antenns
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func antennaListRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio to send a list of antennas
   _api.send(Api.Command.antList.rawValue, replyTo: callback == nil ? defaultReplyHandler : callback)
  }
  
  // MARK: --- ATU ---
  
  /// Clear the ATU
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func atuClear(callback: ReplyHandler? = nil) {
    
    // tell the Radio to clear the ATU
   _api.send(Atu.kClearCmd, replyTo: callback)
  }
  /// Start the ATU
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func atuStart(callback: ReplyHandler? = nil) {
    
    // tell the Radio to start the ATU
   _api.send(Atu.kStartCmd, replyTo: callback)
  }
  /// Bypass the ATU
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func atuBypass(callback: ReplyHandler? = nil) {
    
    // tell the Radio to bypass the ATU
   _api.send(Atu.kBypassCmd, replyTo: callback)
  }
  
  // MARK: --- Audio Stream ---
  
  /// Create an Audio Stream
  ///
  /// - Parameters:
  ///   - channel:            DAX channel number
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func audioStreamCreate(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a Stream
    return _api.sendWithCheck(Radio.kStreamCreateCmd + "dax" + "=\(channel)", replyTo: callback)
  }
  /// Remove an Audio Stream
  ///
  /// - Parameters:
  ///   - id:                 Audio Stream Id
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func audioStreamRemove(_ id: DaxStreamId, callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to remove a Stream
    return _api.sendWithCheck(Radio.kStreamRemoveCmd + "\(id.hex)", replyTo: callback)
  }
  /// Check if an audio stream belongs to us
  ///
  /// - Parameters:
  ///   - keyValues:          a KeyValuesArray of the status message
  ///
  /// - Returns:              result of the check
  ///
  public func isAudioStreamStatusForThisClient(_ properties: KeyValuesArray) -> Bool {
    
    var statusIpStr = ""
    var statusPortStr = ""
    
    // search thru each key/value pair, <key=value>
    for property in properties {
      
      switch property.key.lowercased() {
      case "ip":
        statusIpStr = property.value
      case "port":
        statusPortStr = property.value
      default:
        break
      }
    }
    
    if statusIpStr == "" || statusPortStr == "" {
      return false
    }
    if !statusIpStr.isValidIP4() {
      return false
    }
    guard let statusPort = UInt16(statusPortStr) else {
      return false
    }
    
    // if local check ip and port
    // if remote check only ip
    // TODO: this is a temporary fix and a flaw in Flex way to think.. :-)
    if _api.isWan {
      if _api.localIP == statusIpStr {
        return true
      }
    } else {
      if _api.localIP == statusIpStr && _api.localUDPPort == statusPort {
        return true
      }
    }
    
    return false
  }

  // MARK: --- Client ---
  
  /// Identify a low Bandwidth connection
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func clientLowBandwidthConnect(callback: ReplyHandler? = nil) {
    
    // tell the Radio to limit the connection bandwidth
   _api.send(Api.Command.clientProgram.rawValue + "low_bw_connect", replyTo: callback)
  }
  /// Turn off persistence
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func clientPersistenceOff(callback: ReplyHandler? = nil) {
    
    // tell the Radio to turn off persistence
   _api.send(Api.Command.clientProgram.rawValue + "start_persistence off", replyTo: callback)
  }
  
  // MARK: --- CW ---
  
  /// Key CW
  ///
  /// - Parameters:
  ///   - state:              Key Up = 0, Key Down = 1
  ///   - callback:           ReplyHandler (optional)
  ///
  public func cwKeyImmediate(state: Bool, callback: ReplyHandler? = nil) {
    
    // tell the Radio to change the keydown state
   _api.send(Transmit.kCwCmd + "key immediate" + " \(state.asNumber())", replyTo: callback)
  }
  
  // MARK: --- Equalizer ---
  
  /// Return a list of Equalizer values
  ///
  /// - Parameters:
  ///   - eqType:             Equalizer type raw value of the enum)
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func equalizerInfo(_ eqType: String, callback:  ReplyHandler? = nil) -> Bool {
    
    // ask the Radio for the selected Equalizer settings
    return _api.sendWithCheck(Equalizer.kCmd + eqType + " info", replyTo: callback)
  }
  
  // MARK: --- Gps ---
  
  /// Gps Install
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func gpsInstall(callback: ReplyHandler? = nil) {
    
    // tell the Radio to install the GPS device
   _api.send(Radio.kGpsCmd + "install", replyTo: callback)
  }
  /// Gps Un-Install
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func gpsUnInstall(callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the GPS device
   _api.send(Radio.kGpsCmd + "uninstall", replyTo: callback)
  }
  
  // MARK: --- Iq Stream ---
  
  /// Create an IQ Stream
  ///
  /// - Parameters:
  ///   - channel:            DAX channel number
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func iqStreamCreate(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
    return _api.sendWithCheck(Radio.kStreamCreateCmd + "daxiq" + "=\(channel)", replyTo: callback)
  }
  /// Create an IQ Stream
  ///
  /// - Parameters:
  ///   - channel:            DAX channel number
  ///   - ip:                 ip address
  ///   - port:               port number
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func iqStreamCreate(_ channel: String, ip: String, port: Int, callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create the Stream
    return _api.sendWithCheck(Radio.kStreamCreateCmd + "daxiq" + "=\(channel) " + "ip" + "=\(ip) " + "port" + "=\(port)", replyTo: callback)
  }
  /// Remove an IQ Stream
  ///
  /// - Parameters:
  ///   - id:                 IQ Stream Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func iqStreamRemove(_ id: DaxStreamId, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Stream
   _api.send(Radio.kStreamRemoveCmd + "\(id.hex)", replyTo: callback)
    
    // notify all observers
    NC.post(.iqStreamWillBeRemoved, object: iqStreams[id])
    
    // remove the Stream
    iqStreams[id] = nil
  }
  
  // MARK: --- License ---
  
  /// Refresh the Radio License
  ///
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func refreshLicense(callback: ReplyHandler? = nil) {
    
    // ask the Radio for its license info
    return _api.send(Radio.kLicenseCmd + "refresh", replyTo: callback)
  }
  
  // MARK: --- Memory ---
  
  /// Apply a Memory
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func memoryApply(index: Int, callback: ReplyHandler? = nil) {
    
    // tell the Radio to apply the Memory
   _api.send(Memory.kApplyCmd + "\(index)", replyTo: callback)
  }
  /// Create a Memory
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func memoryCreate(callback: ReplyHandler? = nil) {
    
    // tell the Radio to create a Memory
   _api.send(Memory.kCreateCmd, replyTo: callback)
  }
  /// Remove a Memory
  ///
  /// - Parameters:
  ///   - id:                 Memory Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func memoryRemove(_ id: MemoryId, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Memory
   _api.send(Memory.kRemoveCmd + "\(id)", replyTo: callback)
  }
  
  // MARK: --- Meter ---
  
  /// Request a list of Meters
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func meterListRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio for a list of Meters
   _api.send(Api.Command.meterList.rawValue, replyTo: callback == nil ? defaultReplyHandler : callback)
  }
  
  // MARK: --- Mic Audio Stream ---
  
  /// Create a Mic Audio Stream
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func micAudioStreamCreate(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a Stream
    return _api.sendWithCheck(Radio.kMicStreamCreateCmd, replyTo: callback)
  }
  /// Remove a Mic Audio Stream
  ///
  /// - Parameters:
  ///   - id:                 Mic Audio Stream Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func micAudioStreamRemove(_ id: DaxStreamId, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Stream
   _api.send(Radio.kStreamRemoveCmd + "\(id.hex)", replyTo: callback)
  }
  
  // MARK: --- Mic List ---
  
  /// Request a List of Mic sources
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func micListRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio for a list of Mic Sources
   _api.send(Api.Command.micList.rawValue, replyTo: callback == nil ? defaultReplyHandler : callback)
  }
  
  // MARK: --- Opus ---
  
  /// Remove an Opus Stream
  ///
  /// - Parameters:
  ///   - id:                 Opus Stream Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func opusStreamRemove(_ id: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Stream
   _api.send(Radio.kStreamRemoveCmd + "0x\(id)", replyTo: callback)
  }
  
  // MARK: --- Panafall ---
  
  /// Create a Panafall
  ///
  /// - Parameters:
  ///   - dimensions:         Panafall dimensions
  ///   - callback:           ReplyHandler (optional)
  ///
  public func panafallCreate(_ dimensions: CGSize, callback: ReplyHandler? = nil) {
    
    // tell the Radio to create a Panafall (if any available)
    if availablePanadapters > 0 {
     _api.send(Panadapter.kCmd + "create x=\(dimensions.width) y=\(dimensions.height)", replyTo: callback == nil ? defaultReplyHandler : callback)
    }
  }
  /// Create a Panafall
  ///
  /// - Parameters:
  ///   - frequency:          selected frequency (Hz)
  ///   - antenna:            selected antenna
  ///   - dimensions:         Panafall dimensions
  ///   - callback:           ReplyHandler (optional)
  ///
  public func panafallCreate(frequency: Int, antenna: String? = nil, dimensions: CGSize? = nil, callback: ReplyHandler? = nil) {
    
    // tell the Radio to create a Panafall (if any available)
    if availablePanadapters > 0 {
      
      var cmd = Panadapter.kCreateCmd + "freq" + "=\(frequency.hzToMhz())"
      if antenna != nil { cmd += " ant=" + "\(antenna!)" }
      if dimensions != nil { cmd += " x" + "=\(dimensions!.width)" + " y" + "=\(dimensions!.height)" }
     _api.send(cmd, replyTo: callback == nil ? defaultReplyHandler : callback)
    }
  }
  /// Remove a Panafall
  ///
  /// - Parameters:
  ///   - id:                 Panafall Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func panafallRemove(_ id: PanadapterId, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove a Panafall
   _api.send(Panadapter.kRemoveCmd + "\(id.hex)", replyTo: callback)
  }
  /// Request Click Tune
  ///
  /// - Parameters:
  ///   - frequency:          Frequency (Hz)
  ///   - id:                 Panafall Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func panafallClickTune(_ frequency: Int, id: PanadapterId, callback: ReplyHandler? = nil) {
    
    // FIXME: ???
   _api.send(xLib6000.Slice.kCmd + "m " + "\(frequency.hzToMhz())" + " pan=\(id.hex)", replyTo: callback)
  }
  
  // MARK: --- Profiles ---
  
  /// Delete a Global profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func profileGlobalDelete(_ name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to delete the named Global Profile
   _api.send(Profile.kCmd + Profile.Token.global.rawValue + " delete \"" + name + "\"", replyTo: callback)
  }
  /// Save a Global profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func profileGlobalSave(_ name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to save the named Global Profile
   _api.send(Profile.kCmd + Profile.Token.global.rawValue + " save \"" + name + "\"", replyTo: callback)
  }
  /// Delete a Mic profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func profileMicDelete(_ name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to delete the named Mic Profile
   _api.send(Profile.kCmd + Profile.Token.mic.rawValue + " delete \"" + name + "\"", replyTo: callback)
  }
  /// Save a Mic profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func profileMicSave(_ name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to save the named Mic Profile
   _api.send(Profile.kCmd  + Profile.Token.mic.rawValue + " save \"" + name + "\"", replyTo: callback)
  }
  /// Delete a Transmit profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func profileTransmitDelete(_ name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to delete the named Transmit Profile
   _api.send(Profile.kCmd  + "transmit" + " save \"" + name + "\"", replyTo: callback)
  }
  /// Save a Transmit profile
  ///
  /// - Parameters:
  ///   - name:               profile name
  ///   - callback:           ReplyHandler (optional)
  ///
  public func profileTransmitSave(_ name: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to save the named Transmit Profile
   _api.send(Profile.kCmd  + "transmit" + " save \"" + name + "\"", replyTo: callback)
  }
  
  // MARK: --- Radio ---
  
  /// Reset the Static Net Params
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func staticNetParamsReset(callback: ReplyHandler? = nil) {
    
    // tell the Radio to reset the Static Net Params
   _api.send(Radio.kCmd + RadioToken.staticNetParams.rawValue + " reset", replyTo: callback)
  }
  // MARK: --- Remote Audio (Opus) ---
  
  /// Turn Opus Rx On/Off
  ///
  /// - Parameters:
  ///   - value:              On/Off
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remoteRxAudioRequest(_ value: Bool, callback: ReplyHandler? = nil) {
    
    // tell the Radio to enable Opus Rx
   _api.send(Opus.kCmd + Opus.Token.remoteRxOn.rawValue + " \(value.asNumber())", replyTo: callback)
  }
  
  // MARK: --- Reboot ---
  
  /// Reboot the Radio
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func rebootRequest(callback: ReplyHandler? = nil) {
    
    // tell the Radio to reboot
   _api.send(Radio.kCmd + RadioToken.staticNetParams.rawValue + " reset", replyTo: callback)
  }
  
  // MARK: --- Slice ---
  
  /// Create a new Slice
  ///
  /// - Parameters:
  ///   - frequency:          frequenct (Hz)
  ///   - antenna:            selected antenna
  ///   - mode:               selected mode
  ///   - callback:           ReplyHandler (optional)
  ///
  public func sliceCreate(frequency: Int, antenna: String, mode: String, callback: ReplyHandler? = nil) { if availableSlices > 0 {
    
    // tell the Radio to create a Slice
   _api.send(xLib6000.Slice.kCreateCmd + "\(frequency.hzToMhz()) \(antenna) \(mode)", replyTo: callback) }
  }
  /// Create a new Slice
  ///
  /// - Parameters:
  ///   - panadapter:         selected panadapter
  ///   - frequency:          frequency (Hz)
  ///   - callback:           ReplyHandler (optional)
  ///
  public func sliceCreate(panadapter: Panadapter, frequency: Int = 0, callback: ReplyHandler? = nil) { if availableSlices > 0 {
    
    // tell the Radio to create a Slice
   _api.send(xLib6000.Slice.kCreateCmd + "pan" + "=\(panadapter.id.hex) \(frequency == 0 ? "" : "freq" + "=\(frequency.hzToMhz())")", replyTo: callback) }
  }
  /// Remove a Slice
  ///
  /// - Parameters:
  ///   - id:                 Slice Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func sliceRemove(_ id: SliceId, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove a Slice
   _api.send(xLib6000.Slice.kRemoveCmd + " \(id)", replyTo: callback)
  }
  /// Requent the Slice frequency error values
  ///
  /// - Parameters:
  ///   - id:                 Slice Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func sliceErrorRequest(_ id: SliceId, callback: ReplyHandler? = nil) {
    
    // ask the Radio for the current frequency error
   _api.send(xLib6000.Slice.kCmd + "get_error" + " \(id)", replyTo: callback == nil ? defaultReplyHandler : callback)
  }
  /// Request a list of slice Stream Id's
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  ///
  public func sliceListRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio for a list of Slices
   _api.send(xLib6000.Slice.kCmd + "list", replyTo: callback == nil ? defaultReplyHandler : callback)
  }
  
  // MARK: --- Tnf ---
  
  /// Create a Tnf
  ///
  /// - Parameters:
  ///   - frequency:          frequency (Hz)
  ///   - panadapter:         Panadapter Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func tnfCreate(frequency: Int, panadapter: Panadapter, callback: ReplyHandler? = nil) {
    
    // tell the Radio to create a Tnf
   _api.send(Tnf.kCreateCmd + "freq" + "=\(calcTnfFreq(frequency, panadapter).hzToMhz())", replyTo: callback)
  }
  /// Remove a Tnf
  ///
  /// - Parameters:
  ///   - tnf:                Tnf Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func tnfRemove(tnf: Tnf, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove the Tnf
   _api.send(Tnf.kRemoveCmd + " \(tnf.id)", replyTo: callback)
    
    // notify all observers
    NC.post(.tnfWillBeRemoved, object: tnf as Any?)
    
    // remove the Tnf
    tnfs[tnf.id] = nil
  }
  
  // MARK: --- Transmit ---
  
  /// Turn MOX On/Off
  ///
  /// - Parameters:
  ///   - value:              On/Off
  ///   - callback:           ReplyHandler (optional)
  ///
  public func transmitSet(_ value: Bool, callback: ReplyHandler? = nil) {
    
    // tell the Radio to set MOX
   _api.send(Radio.kXmitCmd + " \(value.asNumber())", replyTo: callback)
  }
  
  // MARK: --- Tx Audio Stream ---
  
  /// Create a Tx Audio Stream
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func txAudioStreamCreate(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a Stream
    return _api.sendWithCheck(Radio.kStreamCreateCmd + "daxtx", replyTo: callback)
  }
  /// Remove a Tx Audio Stream
  ///
  /// - Parameters:
  ///   - id:                 TxAudioStream Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func txAudioStreamRemove(_ id: DaxStreamId, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove a Stream
   _api.send(Radio.kStreamRemoveCmd + "\(id.hex)", replyTo: callback)
  }
  
  // MARK: --- Uptime ---
  
  /// Request the elapsed uptime
  ///
  public func uptimeRequest(callback: ReplyHandler? = nil) {
    
    // ask the Radio for the elapsed uptime
   _api.send(Radio.kUptimeCmd, replyTo: callback == nil ? defaultReplyHandler : callback)
  }
  
  // MARK: --- UsbCable ---
  
  /// Remove a UsbCable
  ///
  /// - Parameters:
  ///   - id:                 UsbCable serial number
  ///   - callback:           ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func usbCableRemove(_ id: String, callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to remove a USB Cable
    return _api.sendWithCheck(UsbCable.kCmd + "remove" + " \(id)")
  }
  
  // MARK: --- Xvtr ---
  
  /// Create an Xvtr
  ///
  /// - Parameter callback:   ReplyHandler (optional)
  /// - Returns:              Success / Failure
  ///
  public func xvtrCreate(callback: ReplyHandler? = nil) -> Bool {
    
    // tell the Radio to create a USB Cable
    return _api.sendWithCheck(Xvtr.kCreateCmd , replyTo: callback)
  }
  /// Remove an Xvtr
  ///
  /// - Parameters:
  ///   - id:                 Xvtr Id
  ///   - callback:           ReplyHandler (optional)
  ///
  public func xvtrRemove(_ id: String, callback: ReplyHandler? = nil) {
    
    // tell the Radio to remove a XVTR
   _api.send(Xvtr.kRemoveCmd + "\(id)", replyTo: callback)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set an Apf property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func apfCmd( _ token: EqApfToken, _ value: Any) {
    
   _api.send(Radio.kApfCmd + token.rawValue + "=\(value)")
  }
  /// Set a Mixer property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func mixerCmd( _ token: String, _ value: Any) {
    
   _api.send(Radio.kMixerCmd + token + " \(value)")
  }
  /// Set a Radio property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func radioSetCmd( _ token: RadioToken, _ value: Any) {
    
   _api.send(Radio.kSetCmd + token.rawValue + "=\(value)")
  }
  /// Set a Radio property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func radioCmd( _ token: RadioToken, _ value: Any) {
    
   _api.send(Radio.kCmd + token.rawValue + " \(value)")
  }
  /// Set a Radio Filter property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func radioFilterCmd( _ token1: RadioToken,  _ token2: RadioToken, _ token3: RadioToken,_ value: Any) {
    
   _api.send(Radio.kCmd + token1.rawValue + " " + token2.rawValue + " " + token3.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (with message sent to Radio)
  
  // listed in alphabetical order
  
  // ***** APF COMMANDS *****
  
  @objc dynamic public var apfEnabled: Bool {
    get {  return _apfEnabled }
    set { if _apfEnabled != newValue { _apfEnabled = newValue ; apfCmd( .mode, newValue.asNumber()) } } }
  
  @objc dynamic public var apfQFactor: Int {
    get {  return _apfQFactor }
    set { if _apfQFactor != newValue { _apfQFactor = newValue.bound(Radio.kMinApfQ, Radio.kMaxApfQ) ; apfCmd( .qFactor, newValue) } } }
  
  @objc dynamic public var apfGain: Int {
    get {  return _apfGain }
    set { if _apfGain != newValue { _apfGain = newValue.bound(Radio.kMin, Radio.kMax) ; apfCmd( .gain, newValue) } } }
  
  // ***** MIXER COMMANDS *****
  
  @objc dynamic public var headphoneGain: Int {
    get {  return _headphoneGain }
    set { if _headphoneGain != newValue { _headphoneGain = newValue.bound(Radio.kMin, Radio.kMax) ; mixerCmd( "headphone gain", newValue) } } }
  
  @objc dynamic public var headphoneMute: Bool {
    get {  return _headphoneMute }
    set { if _headphoneMute != newValue { _headphoneMute = newValue; mixerCmd( "headphone mute", newValue.asNumber()) } } }
  
  @objc dynamic public var lineoutGain: Int {
    get {  return _lineoutGain }
    set { if _lineoutGain != newValue { _lineoutGain = newValue.bound(Radio.kMin, Radio.kMax) ; mixerCmd( "lineout gain", newValue) } } }
  
  @objc dynamic public var lineoutMute: Bool {
    get {  return _lineoutMute }
    set { if _lineoutMute != newValue { _lineoutMute = newValue ; mixerCmd( "lineout mute", newValue.asNumber()) } } }
  
  // ***** RADIO SET COMMANDS *****
  
  @objc dynamic public var bandPersistenceEnabled: Bool {
    get {  return _bandPersistenceEnabled }
    set { if _bandPersistenceEnabled != newValue { _bandPersistenceEnabled = newValue ; radioSetCmd( .bandPersistenceEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var binauralRxEnabled: Bool {
    get {  return _binauralRxEnabled }
    set { if _binauralRxEnabled != newValue { _binauralRxEnabled = newValue ; radioSetCmd( .binauralRxEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var calFreq: Int {
    get {  return _calFreq }
    set { if _calFreq != newValue { _calFreq = newValue ; radioSetCmd( .calFreq, newValue.hzToMhz()) } } }
  
  @objc dynamic public var enforcePrivateIpEnabled: Bool {
    get {  return _enforcePrivateIpEnabled }
    set { if _enforcePrivateIpEnabled != newValue { _enforcePrivateIpEnabled = newValue ; radioSetCmd( .enforcePrivateIpEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var freqErrorPpb: Int {
    get {  return _freqErrorPpb }
    set { if _freqErrorPpb != newValue { _freqErrorPpb = newValue ; radioSetCmd( .freqErrorPpb, newValue) } } }
  
  @objc dynamic public var fullDuplexEnabled: Bool {
    get {  return _fullDuplexEnabled }
    set { if _fullDuplexEnabled != newValue { _fullDuplexEnabled = newValue ; radioSetCmd( .fullDuplexEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var remoteOnEnabled: Bool {
    get {  return _remoteOnEnabled }
    set { if _remoteOnEnabled != newValue { _remoteOnEnabled = newValue ; radioSetCmd( .remoteOnEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var rttyMark: Int {
    get {  return _rttyMark }
    set { if _rttyMark != newValue { _rttyMark = newValue ; radioSetCmd( .rttyMark, newValue) } } }
  
  @objc dynamic public var tnfEnabled: Bool {
    get {  return _tnfEnabled }
    set { if _tnfEnabled != newValue { _tnfEnabled = newValue ; radioSetCmd( .tnfEnabled, newValue.asString()) } } }
  
  // ***** RADIO COMMANDS *****  
  
  // FIXME: command for backlight
  @objc dynamic public var backlight: Int {
    get {  return _backlight }
    set { if _backlight != newValue { _backlight = newValue  } } }
  
  @objc dynamic public var callsign: String {
    get {  return _callsign }
    set { if _callsign != newValue { _callsign = newValue ; radioCmd( .callsign, newValue) } } }
  
  @objc dynamic public var nickname: String {
    get {  return _nickname }
    set { if _nickname != newValue { _nickname = newValue ;_api.send(Radio.kCmd + "name" + " \(newValue)") } } }
  
  @objc dynamic public var radioScreenSaver: String {
    get {  return _radioScreenSaver }
    set { if _radioScreenSaver != newValue { _radioScreenSaver = newValue ;_api.send(Radio.kCmd + "screensaver" + " \(newValue)") } } }
  
  @objc dynamic public var snapTuneEnabled: Bool {
    get {  return _snapTuneEnabled }
    set { if _snapTuneEnabled != newValue { _snapTuneEnabled = newValue ; radioCmd( .snapTuneEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var startOffset: Bool {
    get { return _startOffset }
    set { if _startOffset != newValue { _startOffset = newValue ; if !_startOffset {_api.send(Radio.kCmd + "pll_start") } } } }
  
  // ***** RADIO FILTER COMMANDS *****
  
  @objc dynamic public var filterCwAutoLevel: Int {
    get {  return _filterCwAutoLevel }
    set { if _filterCwAutoLevel != newValue { _filterCwAutoLevel = newValue ; radioFilterCmd( .filterSharpness, .cw, .autoLevel, newValue) } } }
  
  @objc dynamic public var filterDigitalAutoLevel: Int {
    get {  return _filterDigitalAutoLevel }
    set { if _filterDigitalAutoLevel != newValue { _filterDigitalAutoLevel = newValue ; radioFilterCmd( .filterSharpness, .digital, .autoLevel, newValue) } } }
  
  @objc dynamic public var filterVoiceAutoLevel: Int {
    get {  return _filterVoiceAutoLevel }
    set { if _filterVoiceAutoLevel != newValue { _filterVoiceAutoLevel = newValue ; radioFilterCmd( .filterSharpness, .voice, .autoLevel, newValue) } } }
  
  @objc dynamic public var filterCwLevel: Int {
    get {  return _filterCwLevel }
    set { if _filterCwLevel != newValue { _filterCwLevel = newValue ; radioFilterCmd( .filterSharpness, .cw, .level, newValue) } } }
  
  @objc dynamic public var filterDigitalLevel: Int {
    get {  return _filterDigitalLevel }
    set { if _filterDigitalLevel != newValue { _filterDigitalLevel = newValue ; radioFilterCmd( .filterSharpness, .digital, .level, newValue) } } }
  
  @objc dynamic public var filterVoiceLevel: Int {
    get {  return _filterVoiceLevel }
    set { if _filterVoiceLevel != newValue { _filterVoiceLevel = newValue ; radioFilterCmd( .filterSharpness, .voice, .level, newValue) } } }
  
  // ***** RADIO GATEWAY COMMANDS *****
  
  @objc dynamic public var staticGateway: String {
    get {  return _staticGateway }
    set { if _staticGateway != newValue { _staticGateway = newValue ;_api.send(Radio.kCmd + RadioToken.staticNetParams.rawValue + " " + RadioToken.ip.rawValue + "=\(staticIp) " + RadioToken.gateway.rawValue + "=\(newValue) " + RadioToken.netmask.rawValue + "=\(staticNetmask)") } } }
  
  @objc dynamic public var staticIp: String {
    get {  return _staticIp }
    set { if _staticIp != newValue { _staticIp = newValue ;_api.send(Radio.kCmd + RadioToken.staticNetParams.rawValue + " " + RadioToken.ip.rawValue + "=\(staticIp) " + RadioToken.gateway.rawValue + "=\(newValue) " + RadioToken.netmask.rawValue + "=\(staticNetmask)") } } }
  
  @objc dynamic public var staticNetmask: String {
    get {  return _staticNetmask }
    set { if _staticNetmask != newValue { _staticNetmask = newValue ;_api.send(Radio.kCmd + RadioToken.staticNetParams.rawValue + " " + RadioToken.ip.rawValue + "=\(staticIp) " + RadioToken.gateway.rawValue + "=\(newValue) " + RadioToken.netmask.rawValue + "=\(staticNetmask)") } } }
}
