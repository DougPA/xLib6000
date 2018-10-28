//
//  RadioParameters.swift
//  CommonCode
//
//  Created by Douglas Adams on 12/19/16.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - RadioParameters implementation
//
//      structure used internally to represent a Radio (hardware) instance
//
// --------------------------------------------------------------------------------

public final class RadioParameters          : Equatable {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var lastSeen                       : Date                          // data/time last broadcast from Radio

  public var callsign                       : String                        // user assigned call sign
  public var discoveryVersion               : String                        // e.g. 2.0.0.1
  public var fpcMac                         : String                        // ??
  public var firmwareVersion                : String                        // Radio firmware version (e.g. 2.0.1.17)
  public var inUseHost                      : String                        // ??
  public var inUseIp                        : String                        // ??
  public var isPortForwardOn                : Bool
  public var localInterfaceIP               : String
  public var lowBandwidthConnect            : Bool
  public var maxLicensedVersion             : String                        // Highest licensed version
  public var model                          : String                        // Radio model (e.g. FLEX-6500)
  public var negotiatedHolePunchPort        : Int
  public var nickname                       : String                        // user assigned Radio name
  public var port                           : Int                           // port # broadcast received on
  public var publicIp                       : String                        // IP Address (dotted decimal)
  public var publicTlsPort                  : Int
  public var publicUdpPort                  : Int
  public var radioLicenseId                 : String                        // The current License of the Radio
  public var requiresAdditionalLicense      : String                        // License needed?
  public var requiresHolePunch              : Bool
  public var serialNumber                   : String                        // serial number
  public var status                         : String                        // available, in_use, connected, update, etc.
  public var upnpSupported                  : Bool
  public var wanConnected                   : Bool
  
  public var dict                           : [String : Any ] {              // computed dict
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
  
  public enum Param : String {
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
  /// - Parameters:
  ///   - lastSeen:       the DateTime
  ///
  public init(lastSeen: Date = Date(), ipAddress: String = "", port: Int = 0, model: String = "", serialNumber: String = "") {
    
    self.lastSeen                     = lastSeen

    self.callsign                     = ""
    self.discoveryVersion             = ""
    self.fpcMac                       = ""
    self.firmwareVersion              = ""
    self.inUseHost                    = ""
    self.inUseIp                      = ""
    self.isPortForwardOn              = false
    self.localInterfaceIP             = "0.0.0.0"
    self.lowBandwidthConnect          = false
    self.maxLicensedVersion           = ""
    self.model                        = model
    self.negotiatedHolePunchPort      = -1 // This is invalid until negotiated
    self.nickname                     = ""
    self.port                         = port
    self.publicIp                     = ipAddress
    self.publicTlsPort                = 0
    self.publicUdpPort                = 0
    self.radioLicenseId               = ""
    self.requiresAdditionalLicense    = ""
    self.requiresHolePunch            = false
    self.serialNumber                 = serialNumber
    self.status                       = ""
    self.upnpSupported                = false
    self.wanConnected                 = false
  }
  /// Initialize a RadioParameters instance from a dictionary
  ///
  /// - Parameters:
  ///   - dict:           a Dictionary of Values
  ///
  public init(_ dict: [String : Any]) {
    
    // lastSeen will be "Now"
    self.lastSeen                           = Date()
    
    self.callsign                           = dict[Param.callsign.rawValue] as? String ?? ""
    self.discoveryVersion                   = dict[Param.discoveryVersion.rawValue] as? String ?? ""
    self.fpcMac                             = dict[Param.fpcMac.rawValue] as? String ?? ""
    self.firmwareVersion                    = dict[Param.firmwareVersion.rawValue] as? String ?? ""
    self.inUseHost                          = dict[Param.inUseHost.rawValue] as? String ?? ""
    self.inUseIp                            = dict[Param.inUseHost.rawValue] as? String ?? ""
    self.isPortForwardOn                    = dict[Param.isPortForwardOn.rawValue] as? Bool ?? false
    self.localInterfaceIP                   = dict[Param.localInterfaceIP.rawValue] as? String ?? "0.0.0.0"
    self.lowBandwidthConnect                = dict[Param.lowBandwidthConnect.rawValue] as? Bool ?? false
    self.maxLicensedVersion                 = dict[Param.maxLicensedVersion.rawValue] as? String ?? ""
    self.model                              = dict[Param.model.rawValue] as? String ?? ""
    self.negotiatedHolePunchPort            = dict[Param.negotiatedHolePunchPort.rawValue] as? Int ?? -1
    self.nickname                           = dict[Param.nickname.rawValue] as? String ?? ""
    self.port                               = dict[Param.port.rawValue] as? Int ?? 0
    self.publicIp                           = dict[Param.publicIp.rawValue] as? String ?? ""
    self.publicTlsPort                      = dict[Param.publicTlsPort.rawValue] as? Int ?? 0
    self.publicUdpPort                      = dict[Param.publicUdpPort.rawValue] as? Int ?? 0
    self.radioLicenseId                     = dict[Param.radioLicenseId.rawValue] as? String ?? ""
    self.requiresAdditionalLicense          = dict[Param.requiresAdditionalLicense.rawValue] as? String ?? ""
    self.requiresHolePunch                  = dict[Param.requiresHolePunch.rawValue] as? Bool ?? false
    self.serialNumber                       = dict[Param.serialNumber.rawValue] as? String ?? ""
    self.status                             = dict[Param.status.rawValue] as? String ?? ""
    self.upnpSupported                      = dict[Param.upnpSupported.rawValue] as? Bool ?? false
    self.wanConnected                       = dict[Param.wanConnected.rawValue] as? Bool ?? false
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
  public func valueForName(_ propertyName: String) -> String? {
    
    switch propertyName {
      
    case Param.callsign.rawValue:
      return callsign
      
    case Param.discoveryVersion.rawValue:
      return discoveryVersion
      
    case Param.fpcMac.rawValue:
      return fpcMac
      
    case Param.firmwareVersion.rawValue:
      return firmwareVersion
      
    case Param.inUseHost.rawValue:
      return inUseHost
      
    case Param.inUseHost.rawValue:
      return inUseIp
      
    case Param.isPortForwardOn.rawValue:
      return isPortForwardOn.description
      
    case Param.lastSeen.rawValue:
      return lastSeen.description
      
    case Param.localInterfaceIP.rawValue:
      return localInterfaceIP
      
    case Param.lowBandwidthConnect.rawValue:
      return lowBandwidthConnect.description
      
    case Param.maxLicensedVersion.rawValue:
      return maxLicensedVersion
      
    case Param.model.rawValue:
      return model
      
    case Param.nickname.rawValue:
      return nickname
      
    case Param.port.rawValue:
      return port.description
      
    case Param.publicIp.rawValue:
      return publicIp

    case Param.publicTlsPort.rawValue:
      return publicTlsPort.description
      
    case Param.publicUdpPort.rawValue:
      return publicUdpPort.description
      
    case Param.radioLicenseId.rawValue:
      return radioLicenseId
      
//    case Param.radioName.rawValue:
//      return radioName
      
    case Param.requiresAdditionalLicense.rawValue:
      return requiresAdditionalLicense
      
    case Param.requiresHolePunch.rawValue:
      return requiresHolePunch.description
      
    case Param.serialNumber.rawValue:
      return serialNumber
      
    case Param.status.rawValue:
      return status
      
    case Param.upnpSupported.rawValue:
      return upnpSupported.description
      
    case Param.wanConnected.rawValue:
      return wanConnected.description
      
    default:
      return "Unknown"
    }
  }
}
