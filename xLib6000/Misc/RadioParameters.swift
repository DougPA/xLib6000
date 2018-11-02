//
//  RadioParameters.swift
//  CommonCode
//
//  Created by Douglas Adams on 12/19/16.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import os.log

// --------------------------------------------------------------------------------
// MARK: - RadioParameters implementation
//
//      structure used internally to represent a Radio (hardware) instance
//
// --------------------------------------------------------------------------------

public final class RadioParameters          : Equatable {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var lastSeen                       = Date()                        // data/time last broadcast from Radio

  public var callsign                       = ""                            // user assigned call sign
  public var discoveryVersion               = ""                            // e.g. 2.0.0.1
  public var firmwareVersion                = ""                            // Radio firmware version (e.g. 2.0.1.17)
  public var fpcMac                         = ""                            // ??
  public var inUseHost                      = ""                            // ??
  public var inUseIp                        = ""                            // ??
  public var isPortForwardOn                = false
  public var localInterfaceIP               = ""
  public var lowBandwidthConnect            = false
  public var maxLicensedVersion             = ""                            // Highest licensed version
  public var model                          = ""                            // Radio model (e.g. FLEX-6500)
  public var negotiatedHolePunchPort        = -1
  public var nickname                       = ""                            // user assigned Radio name
  public var port                           = -1                            // port # broadcast received on
  public var publicIp                       = ""                            // IP Address (dotted decimal)
  public var publicTlsPort                  = -1
  public var publicUdpPort                  = -1
  public var radioLicenseId                 = ""                            // The current License of the Radio
  public var requiresAdditionalLicense      = ""                            // License needed?
  public var requiresHolePunch              = false
  public var serialNumber                   = ""                            // serial number
  public var status                         = ""                            // available, in_use, connected, update, etc.
  public var upnpSupported                  = false
  public var wanConnected                   = false
  
  public var dict                           : [String : Any ] {             // computed dict
    get {
      
      var dict = [String : Any]()
      
      dict[Param.callsign.rawValue]                       = callsign
      dict[Param.discoveryVersion.rawValue]               = discoveryVersion
      dict[Param.fpcMac.rawValue]                         = fpcMac
      dict[Param.firmwareVersion.rawValue]                = firmwareVersion
      dict[Param.inUseHost.rawValue]                      = inUseHost
      dict[Param.inUseIp.rawValue]                        = inUseIp
      dict[Param.isPortForwardOn.rawValue]                = isPortForwardOn
      dict[Param.localInterfaceIP.rawValue]               = localInterfaceIP
      dict[Param.lowBandwidthConnect.rawValue]            = lowBandwidthConnect
      dict[Param.maxLicensedVersion.rawValue]             = maxLicensedVersion
      dict[Param.model.rawValue]                          = model
      dict[Param.negotiatedHolePunchPort.rawValue]        = negotiatedHolePunchPort
      dict[Param.nickname.rawValue]                       = nickname
      dict[Param.port.rawValue]                           = port
      dict[Param.publicIp.rawValue]                       = publicIp
      dict[Param.publicTlsPort.rawValue]                  = publicTlsPort
      dict[Param.publicUdpPort.rawValue]                  = publicUdpPort
      dict[Param.radioLicenseId.rawValue]                 = radioLicenseId
      dict[Param.requiresAdditionalLicense.rawValue]      = requiresAdditionalLicense
      dict[Param.requiresHolePunch.rawValue]              = requiresHolePunch
      dict[Param.serialNumber.rawValue]                   = serialNumber
      dict[Param.status.rawValue]                         = status
      dict[Param.upnpSupported.rawValue]                  = upnpSupported
      dict[Param.wanConnected.rawValue]                   = wanConnected
      
      return dict
    }
  }

  public var description                    : String {                    // computed description
    
    // get the keys sorted
    let sortedKeys = Array(dict.keys).sorted(by: < )
    
    // add each key and value into the string
    var string = "Radio Parameters\n\n"
    sortedKeys.forEach( { key in string += "\(key) = \(dict[key]!)\n" } )
    
    return string
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "RadioParameters")

  private enum Param : String {
    case lastSeen
    
    case callsign
    case discoveryVersion
    case fpcMac
    case firmwareVersion
    case inUseHost
    case inUseIp
    case isPortForwardOn
    case localInterfaceIP
    case lowBandwidthConnect
    case maxLicensedVersion
    case model
    case negotiatedHolePunchPort
    case nickname
    case port
    case publicIp
    case publicTlsPort
    case publicUdpPort
    case radioLicenseId
    case requiresAdditionalLicense
    case requiresHolePunch
    case serialNumber
    case status
    case upnpSupported
    case wanConnected
  }

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize an empty RadioParameters struct
  ///
  public init() {
    
  }
  /// Initialize a RadioParameters instance from a dictionary
  ///
  /// - Parameters:
  ///   - dict:           a Dictionary of Values
  ///
  public init(_ dict: [String : Any]) {
    
    // lastSeen will be "Now"
    lastSeen                                 = Date()
    
    callsign                                = dict[Param.callsign.rawValue] as? String ?? ""
    discoveryVersion                        = dict[Param.discoveryVersion.rawValue] as? String ?? ""
    fpcMac                                  = dict[Param.fpcMac.rawValue] as? String ?? ""
    firmwareVersion                         = dict[Param.firmwareVersion.rawValue] as? String ?? ""
    inUseHost                               = dict[Param.inUseHost.rawValue] as? String ?? ""
    inUseIp                                 = dict[Param.inUseHost.rawValue] as? String ?? ""
    isPortForwardOn                         = dict[Param.isPortForwardOn.rawValue] as? Bool ?? false
    localInterfaceIP                        = dict[Param.localInterfaceIP.rawValue] as? String ?? "0.0.0.0"
    lowBandwidthConnect                     = dict[Param.lowBandwidthConnect.rawValue] as? Bool ?? false
    maxLicensedVersion                      = dict[Param.maxLicensedVersion.rawValue] as? String ?? ""
    model                                   = dict[Param.model.rawValue] as? String ?? ""
    negotiatedHolePunchPort                 = dict[Param.negotiatedHolePunchPort.rawValue] as? Int ?? -1
    nickname                                = dict[Param.nickname.rawValue] as? String ?? ""
    port                                    = dict[Param.port.rawValue] as? Int ?? 0
    publicIp                                = dict[Param.publicIp.rawValue] as? String ?? ""
    publicTlsPort                           = dict[Param.publicTlsPort.rawValue] as? Int ?? 0
    publicUdpPort                           = dict[Param.publicUdpPort.rawValue] as? Int ?? 0
    radioLicenseId                          = dict[Param.radioLicenseId.rawValue] as? String ?? ""
    requiresAdditionalLicense               = dict[Param.requiresAdditionalLicense.rawValue] as? String ?? ""
    requiresHolePunch                       = dict[Param.requiresHolePunch.rawValue] as? Bool ?? false
    serialNumber                            = dict[Param.serialNumber.rawValue] as? String ?? ""
    status                                  = dict[Param.status.rawValue] as? String ?? ""
    upnpSupported                           = dict[Param.upnpSupported.rawValue] as? Bool ?? false
    wanConnected                            = dict[Param.wanConnected.rawValue] as? Bool ?? false
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Static methods
  
  /// Returns a Boolean value indicating whether two RadioParameter instances are equal.
  ///
  /// - Parameters:
  ///   - lhs:            A value to compare.
  ///   - rhs:            Another value to compare.
  ///
  public static func ==(lhs: RadioParameters, rhs: RadioParameters) -> Bool {
    return lhs.serialNumber == rhs.serialNumber
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  ///  Return a String value given a property name
  ///
  /// - Parameters:
  ///   - id:         a Property Name
  /// - Returns:      String value of the Property
  ///
  public func valueForName(_ propertyName: String) -> String {
    
    // check for unknown keys
    guard let token = Param(rawValue: propertyName) else {
      
      // log it and ignore the Key
      os_log("Unknown Radio Param token - %{public}@", log: _log, type: .default, propertyName)
      
      return ""
    }

    return dict[token.rawValue] as? String ?? ""
  }
}
