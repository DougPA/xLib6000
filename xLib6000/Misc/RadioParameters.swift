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
  
  public var callsign                       : String?                       // user assigned call sign
  public var fpcMac                         : String?                       // ??
  public var lastSeen                       : Date                          // data/time last broadcast from Radio
  public var firmwareVersion                : String?                       // Radio firmware version (e.g. 2.0.1.17)
  public var inUseHost                      : String?                       // ??
  public var inUseIp                        : String?                       // ??
  public var ipAddress                      : String                        // IP Address (dotted decimal)
  public var isPortForwardOn                : Bool
  public var localInterfaceIP               : String
  public var lowBandwidthConnect            : Bool
  public var maxLicensedVersion             : String?                       // Highest licensed version
  public var model                          : String                        // Radio model (e.g. FLEX-6500)
  public var name                           : String?                       // ??
  public var negotiatedHolePunchPort        : Int
  public var nickname                       : String?                       // user assigned Radio name
  public var port                           : Int                           // port # broadcast received on
  public var protocolVersion                : String?                       // e.g. 2.0.0.1
  public var publicTlsPort                  : Int
  public var publicUdpPort                  : Int
  public var radioLicenseId                 : String?                       // The current License of the Radio
  public var requiresAdditionalLicense      : String?                       // License needed?
  public var requiresHolePunch              : Bool
  public var serialNumber                   : String                        // serial number
  public var status                         : String?                       // available, in_use, connected, update, etc.
  public var upnpSupported                  : Bool
  public var wanConnected                   : Bool


  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  enum RadioProperties : String {
    case lastSeen
    case callsign
    case fpcMac
    case firmwareVersion
    case inUseHost
    case ipAddress
    case isPortForwardOn
    case localInterfaceIP
    case lowBandwidthConnect
    case maxLicensedVersion
    case model
    case name
    case negotiatedHolePunchPort
    case nickname
    case port
    case protocolVersion
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
    
    self.ipAddress                    = ipAddress
    self.isPortForwardOn              = false
    self.lastSeen                     = lastSeen
    self.localInterfaceIP             = "0.0.0.0"
    self.lowBandwidthConnect          = false
    self.model                        = model
    self.negotiatedHolePunchPort      = -1 // This is invalid until negotiated
    self.port                         = port
    self.publicTlsPort                = 0
    self.publicUdpPort                = 0
    self.requiresHolePunch            = false
    self.serialNumber                 = serialNumber
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
    self.lastSeen                     = Date()
    
    self.callsign                     = dict[RadioProperties.callsign.rawValue] as? String ?? ""
    self.fpcMac                       = dict[RadioProperties.fpcMac.rawValue] as? String ?? ""
    self.firmwareVersion              = dict[RadioProperties.firmwareVersion.rawValue] as? String ?? ""
    self.inUseHost                    = dict[RadioProperties.inUseHost.rawValue] as? String ?? ""
    self.inUseIp                      = dict[RadioProperties.inUseHost.rawValue] as? String ?? ""
    self.ipAddress                    = dict[RadioProperties.ipAddress.rawValue] as? String ?? ""
    self.isPortForwardOn              = dict[RadioProperties.isPortForwardOn.rawValue] as? Bool ?? false
    self.localInterfaceIP             = dict[RadioProperties.localInterfaceIP.rawValue] as? String ?? "0.0.0.0"
    self.lowBandwidthConnect          = dict[RadioProperties.lowBandwidthConnect.rawValue] as? Bool ?? false
    self.maxLicensedVersion           = dict[RadioProperties.maxLicensedVersion.rawValue] as? String ?? ""
    self.model                        = dict[RadioProperties.model.rawValue] as? String ?? ""
    self.name                         = dict[RadioProperties.name.rawValue] as? String ?? ""
    self.negotiatedHolePunchPort      = dict[RadioProperties.negotiatedHolePunchPort.rawValue] as? Int ?? -1
    self.nickname                     = dict[RadioProperties.nickname.rawValue] as? String ?? ""
    self.port                         = dict[RadioProperties.port.rawValue] as? Int ?? 0
    self.protocolVersion              = dict[RadioProperties.protocolVersion.rawValue] as? String ?? ""
    self.publicTlsPort                = dict[RadioProperties.publicTlsPort.rawValue] as? Int ?? 0
    self.publicUdpPort                = dict[RadioProperties.publicUdpPort.rawValue] as? Int ?? 0
    self.radioLicenseId               = dict[RadioProperties.radioLicenseId.rawValue] as? String ?? ""
    self.requiresAdditionalLicense    = dict[RadioProperties.requiresAdditionalLicense.rawValue] as? String ?? ""
    self.requiresHolePunch            = dict[RadioProperties.requiresHolePunch.rawValue] as? Bool ?? false
    self.serialNumber                 = dict[RadioProperties.serialNumber.rawValue] as? String ?? ""
    self.status                       = dict[RadioProperties.status.rawValue] as? String ?? ""
    self.upnpSupported                = dict[RadioProperties.upnpSupported.rawValue] as? Bool ?? false
    self.wanConnected                 = dict[RadioProperties.wanConnected.rawValue] as? Bool ?? false
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
    return ( lhs.serialNumber == rhs.serialNumber ) && ( lhs.ipAddress == rhs.ipAddress )
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  public func dictFromParams() -> [String : Any ] {
    
    var dict = [String : Any]()
    
    dict[RadioProperties.callsign.rawValue]                   = self.callsign
    dict[RadioProperties.fpcMac.rawValue]                     = self.fpcMac
    dict[RadioProperties.firmwareVersion.rawValue]            = self.firmwareVersion
    dict[RadioProperties.inUseHost.rawValue]                  = self.inUseHost
    dict[RadioProperties.inUseHost.rawValue]                  = self.inUseIp
    dict[RadioProperties.ipAddress.rawValue]                  = self.ipAddress
    dict[RadioProperties.isPortForwardOn.rawValue]            = self.isPortForwardOn
    dict[RadioProperties.localInterfaceIP.rawValue]           = self.localInterfaceIP
    dict[RadioProperties.lowBandwidthConnect.rawValue]        = self.lowBandwidthConnect
    dict[RadioProperties.maxLicensedVersion.rawValue]         = self.maxLicensedVersion
    dict[RadioProperties.model.rawValue]                      = self.model
    dict[RadioProperties.name.rawValue]                       = self.name
    dict[RadioProperties.negotiatedHolePunchPort.rawValue]    = self.negotiatedHolePunchPort
    dict[RadioProperties.nickname.rawValue]                   = self.nickname
    dict[RadioProperties.port.rawValue]                       = self.port
    dict[RadioProperties.protocolVersion.rawValue]            = self.protocolVersion
    dict[RadioProperties.publicTlsPort.rawValue]              = self.publicTlsPort
    dict[RadioProperties.publicUdpPort.rawValue]              = self.publicUdpPort
    dict[RadioProperties.radioLicenseId.rawValue]             = self.radioLicenseId
    dict[RadioProperties.requiresAdditionalLicense.rawValue]  = self.requiresAdditionalLicense
    dict[RadioProperties.requiresHolePunch.rawValue]          = self.requiresHolePunch
    dict[RadioProperties.serialNumber.rawValue]               = self.serialNumber
    dict[RadioProperties.status.rawValue]                     = self.status
    dict[RadioProperties.upnpSupported.rawValue]              = self.upnpSupported
    dict[RadioProperties.wanConnected.rawValue]               = self.wanConnected

    return dict
  }
  ///  Return a String value given a property name
  ///
  /// - Parameters:
  ///   - id:         a Property Name
  /// - Returns:      String value of the Property
  ///
  public func valueForName(_ propertyName: String) -> String? {
    
    switch propertyName {
      
    case RadioProperties.callsign.rawValue:
      return callsign
      
    case RadioProperties.fpcMac.rawValue:
      return fpcMac
      
    case RadioProperties.firmwareVersion.rawValue:
      return firmwareVersion
      
    case RadioProperties.inUseHost.rawValue:
      return inUseHost
      
    case RadioProperties.inUseHost.rawValue:
      return inUseIp
      
    case RadioProperties.ipAddress.rawValue:
      return ipAddress
      
    case RadioProperties.isPortForwardOn.rawValue:
      return isPortForwardOn.description
      
    case RadioProperties.lastSeen.rawValue:
      return lastSeen.description
      
    case RadioProperties.localInterfaceIP.rawValue:
      return localInterfaceIP
      
    case RadioProperties.lowBandwidthConnect.rawValue:
      return lowBandwidthConnect.description
      
    case RadioProperties.maxLicensedVersion.rawValue:
      return maxLicensedVersion
      
    case RadioProperties.model.rawValue:
      return model
      
    case RadioProperties.name.rawValue:
      return name
      
    case RadioProperties.nickname.rawValue:
      return nickname
      
    case RadioProperties.port.rawValue:
      return port.description
      
    case RadioProperties.protocolVersion.rawValue:
      return protocolVersion
      
    case RadioProperties.publicTlsPort.rawValue:
      return publicTlsPort.description
      
    case RadioProperties.publicUdpPort.rawValue:
      return publicUdpPort.description
      
    case RadioProperties.radioLicenseId.rawValue:
      return radioLicenseId
      
    case RadioProperties.requiresAdditionalLicense.rawValue:
      return requiresAdditionalLicense
      
    case RadioProperties.requiresHolePunch.rawValue:
      return requiresHolePunch.description
      
    case RadioProperties.serialNumber.rawValue:
      return serialNumber
      
    case RadioProperties.status.rawValue:
      return status
      
    case RadioProperties.upnpSupported.rawValue:
      return upnpSupported.description
      
    case RadioProperties.wanConnected.rawValue:
      return wanConnected.description
      
    default:
      return "Unknown"
    }
  }

  /// Provide a sorted list of the Radio Parameters in a String
  ///
  /// - Returns:          a String
  ///
  public func description() -> String {
  
    // get the parameters dictionary
    let dict = dictFromParams()
    
    // get the keys sorted
    let sortedKeys = Array(dict.keys).sorted(by:<)
    
    // add each key and value into the string
    var string = "Radio Parameters\n\n"
    sortedKeys.forEach( { key in string += "\(key) = \(dict[key]!)\n" } )

    return string
  }
}
