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
  public var upnpSupported: Bool


  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let kLastSeen                     = "lastSeen"
  private let kCallsign                     = "callsign"
  private let kFpcMac                       = "fpcMac"
  private let kFirmwareVersion              = "firmwareVersion"
  private let kInUseHost                    = "inUseHost"
  private let kIpAddress                    = "ipAddress"
  private let kIsPortForwardOn              = "isPortForwardOn"
  private let kLocalInterfaceIP             = "localInterfaceIP"
  private let kLowBandwidthConnect          = "lowBandwidthConnect"
  private let kMaxLicensedVersion           = "maxLicensedVersion"
  private let kModel                        = "model"
  private let kName                         = "name"
  private let kNegotiatedHolePunchPort     = "negotiatedHolePunchPort"
  private let kNickname                     = "nickname"
  private let kPort                         = "port"
  private let kProtocolVersion              = "protocolVersion"
  private let kPublicTlsPort                = "publicTlsPort"
  private let kPublicUdpPort                = "publicUdpPort"
  private let kRadioLicenseId               = "radioLicenseId"
  private let kRequiresAdditionalLicense    = "requiresAdditionalLicense"
  private let kRequiresHolePunch            = "requiresHolePunch"
  private let kSerialNumber                 = "serialNumber"
  private let kStatus                       = "status"
  private let kUpnpSupported                = "upnpSupported"


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
  }
  /// Initialize a RadioParameters instance from a dictionary
  ///
  /// - Parameters:
  ///   - dict:           a Dictionary of Values
  ///
  public init(_ dict: [String : Any]) {
    
    // lastSeen will be "Now"
    self.lastSeen                     = Date()
    
    self.callsign                     = dict[kCallsign] as? String ?? ""
    self.fpcMac                       = dict[kFpcMac] as? String ?? ""
    self.firmwareVersion              = dict[kFirmwareVersion] as? String ?? ""
    self.inUseHost                    = dict[kInUseHost] as? String ?? ""
    self.inUseIp                      = dict[kInUseHost] as? String ?? ""
    self.ipAddress                    = dict[kIpAddress] as? String ?? ""
    self.isPortForwardOn              = dict[kIsPortForwardOn] as? Bool ?? false
    self.localInterfaceIP             = dict[kLocalInterfaceIP] as? String ?? "0.0.0.0"
    self.lowBandwidthConnect          = dict[kLowBandwidthConnect] as? Bool ?? false
    self.maxLicensedVersion           = dict[kMaxLicensedVersion] as? String ?? ""
    self.model                        = dict[kModel] as? String ?? ""
    self.name                         = dict[kName] as? String ?? ""
    self.negotiatedHolePunchPort      = dict[kNegotiatedHolePunchPort] as? Int ?? -1
    self.nickname                     = dict[kNickname] as? String ?? ""
    self.port                         = dict[kPort] as? Int ?? 0
    self.protocolVersion              = dict[kProtocolVersion] as? String ?? ""
    self.publicTlsPort                = dict[kPublicTlsPort] as? Int ?? 0
    self.publicUdpPort                = dict[kPublicUdpPort] as? Int ?? 0
    self.radioLicenseId               = dict[kRadioLicenseId] as? String ?? ""
    self.requiresAdditionalLicense    = dict[kRequiresAdditionalLicense] as? String ?? ""
    self.requiresHolePunch            = dict[kRequiresHolePunch] as? Bool ?? false
    self.serialNumber                 = dict[kSerialNumber] as? String ?? ""
    self.status                       = dict[kStatus] as? String ?? ""
    self.upnpSupported                = dict[kUpnpSupported] as? Bool ?? false

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
    
    dict[kCallsign]                   = self.callsign
    dict[kFpcMac]                     = self.fpcMac
    dict[kFirmwareVersion]            = self.firmwareVersion
    dict[kInUseHost]                  = self.inUseHost
    dict[kInUseHost]                  = self.inUseIp
    dict[kIpAddress]                  = self.ipAddress
    dict[kIsPortForwardOn]            = self.isPortForwardOn
    dict[kLocalInterfaceIP]           = self.localInterfaceIP
    dict[kLowBandwidthConnect]        = self.lowBandwidthConnect
    dict[kMaxLicensedVersion]         = self.maxLicensedVersion
    dict[kModel]                      = self.model
    dict[kName]                       = self.name
    dict[kNegotiatedHolePunchPort]    = self.negotiatedHolePunchPort
    dict[kNickname]                   = self.nickname
    dict[kPort]                       = self.port
    dict[kProtocolVersion]            = self.protocolVersion
    dict[kPublicTlsPort]              = self.publicTlsPort
    dict[kPublicUdpPort]              = self.publicUdpPort
    dict[kRadioLicenseId]             = self.radioLicenseId
    dict[kRequiresAdditionalLicense]  = self.requiresAdditionalLicense
    dict[kRequiresHolePunch]          = self.requiresHolePunch
    dict[kSerialNumber]               = self.serialNumber
    dict[kStatus]                     = self.status
    dict[kUpnpSupported]              = self.upnpSupported

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
      
    case kCallsign:
      return callsign
      
    case kFpcMac:
      return fpcMac
      
    case kFirmwareVersion:
      return firmwareVersion
      
    case kInUseHost:
      return inUseHost
      
    case kInUseHost:
      return inUseIp
      
    case kIpAddress:
      return ipAddress
      
    case kIsPortForwardOn:
      return isPortForwardOn.description

    case kLastSeen:
      return lastSeen.description
      
    case kLocalInterfaceIP:
      return localInterfaceIP

    case kLowBandwidthConnect:
      return lowBandwidthConnect.description

    case kMaxLicensedVersion:
      return maxLicensedVersion
      
    case kModel:
      return model
      
    case kName:
      return name
      
    case kNickname:
      return nickname
      
    case kPort:
      return port.description
      
    case kProtocolVersion:
      return protocolVersion
      
    case kPublicTlsPort:
      return publicTlsPort.description

    case kPublicUdpPort:
      return publicUdpPort.description

    case kRadioLicenseId:
      return radioLicenseId
      
    case kRequiresAdditionalLicense:
      return requiresAdditionalLicense
      
    case kRequiresHolePunch:
      return requiresHolePunch.description

    case kSerialNumber:
      return serialNumber
      
    case kStatus:
      return status

    case kUpnpSupported:
      return upnpSupported.description

    default:
      return "Unknown"
    }
  }
}
