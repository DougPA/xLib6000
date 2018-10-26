//
//  WanServer.swift
//  CommonCode
//
//  Created by Mario Illgen on 09.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Cocoa
import os

// --------------------------------------------------------------------------------
// MARK: - WanServer structures

public struct WanUserSettings {

  public var callsign   : String
  public var firstName  : String
  public var lastName   : String

  init(callsign: String, firstName: String, lastName: String) {

    self.callsign       = callsign
    self.firstName      = firstName
    self.lastName       = lastName
  }
}

public struct WanTestConnectionResults {

  public var upnpTcpPortWorking         = false
  public var upnpUdpPortWorking         = false
  public var forwardTcpPortWorking      = false
  public var forwardUdpPortWorking      = false
  public var natSupportsHolePunch       = false
  public var radioSerial                = ""

  public func string() -> String {
    return "UPNP TCP Working: \(upnpTcpPortWorking.description)" +
      "\nUPNP UDP Working: \(upnpUdpPortWorking.description)" +
      "\nForwarded TCP Working: \(forwardTcpPortWorking.description)" +
      "\nForwarded UDP Working: \(forwardUdpPortWorking.description)" +
    "\nNAT Preserves Ports: \(natSupportsHolePunch.description)"
  }
}

// --------------------------------------------------------------------------------
// MARK: - WanServerDelegate protocol
//
// --------------------------------------------------------------------------------

public protocol WanServerDelegate           : class {

  /// Received radio list from server
  ///
  func wanRadioListReceived(wanRadioList: [RadioParameters])
  
  /// Received user settings from server
  ///
  func wanUserSettings(_ userSettings: WanUserSettings)
  
  /// Radio is ready to connect
  ///
  func wanRadioConnectReady(handle: String, serial: String)
  
  /// Received Wan test results
  ///
  func wanTestConnectionResultsReceived(results: WanTestConnectionResults)
}

// --------------------------------------------------------------------------------
// MARK: - WanServer Class implementation
//
//      creates a WanServer instance to communicate with the SmartLink server
//      to get access to a remote Flexradio
//
// --------------------------------------------------------------------------------

public final class WanServer                : NSObject, GCDAsyncSocketDelegate {

  static let kAddress                       = "smartlink.flexradio.com"
  static let kPort                          = 443
  public static let kDefaultTimeout         = 0.5

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private weak var _delegate                : WanServerDelegate?

  private var _log                          = OSLog(subsystem:Api.kBundleIdentifier, category: "WanServer")
  private let _api                          = Api.sharedInstance
  private var _appName                      = ""
  private var _currentHost                  = ""
  private var _currentPort                  : UInt16 = 0
  private var _platform                     = ""
  private var _ping                         = false
  private var _pingTimer                    : DispatchSourceTimer?          // periodic timer for ping
  private var _timeout                      = 0.0                           // timeout in seconds
  private var _tlsSocket                    : GCDAsyncSocket!
  private var _token                        = ""

  private let _objectQ                      = DispatchQueue(label: Api.kId + ".WanServer.objectQ")
  private let _pingQ                        = DispatchQueue(label: Api.kId + ".WanServer.pingQ")
  private let _socketQ                      = DispatchQueue(label: Api.kId + ".WanServer.socketQ")

  private let kAppConnectCmd                = "application connect serial"
  private let kAppRegisterCmd               = "application register name"
  private let kDisconnectUsersCmd           = "application disconnect_users serial"
  private let kHolePunchPort                = "hole_punch_port"
  private let kPingServerCmd                = "ping from client"
  private let kPlatform                     = "platform"
  private let kTestCmd                      = "application test_connection serial"
  private let kToken                        = "token"

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var __hostName                    = WanServer.kAddress            // SmartLink server address
  private var __hostPort                    = WanServer.kPort               // SmartLink server SSL port
  private var __isConnected                 = false
  private var __sslClientPublicIp           = ""                            // public IP of the radio
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(delegate: WanServerDelegate?, timeout: Double = WanServer.kDefaultTimeout) {
    
    _timeout = timeout
    _delegate = delegate
    
    super.init()
    
    // get a WAN server socket & set it's parameters
    _tlsSocket = GCDAsyncSocket(delegate: self, delegateQueue: _socketQ)
    _tlsSocket.isIPv4PreferredOverIPv6 = true
    _tlsSocket.isIPv6Enabled = false
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods that send commands to the SmartLink server
  
  /// Initiate a connection to the SmartLink server
  ///
  /// - Parameters:
  ///   - appName:                    application name
  ///   - platform:                   platform
  ///   - token:                      token
  ///   - ping:                       ping enabled
  /// - Returns:                      success / failure
  ///
  public func connect(appName: String, platform: String, token: String, ping: Bool = false) -> Bool {
    
    var success = true
    
    _appName = appName
    _platform = platform
    _token = token
    _ping = ping
    
    // try to connect
    do {
      try _tlsSocket.connect(toHost: _hostName, onPort: UInt16(_hostPort), withTimeout: _timeout)
    } catch _ {
      success = false
    }
    return success
  }
  /// Disconnect from the SmartLink server
  ///
  public func disconnect() {
    
    _tlsSocket.disconnect()
  }
  /// Initiate a connection to radio
  ///
  /// - Parameters:
  ///   - radioSerial:              a radio serial number
  ///   - holePunchPort:            a port number
  ///
  public func sendConnectMessageForRadio(radioSerial: String, holePunchPort: Int = 0) {
    
    guard _isConnected else {
      
      os_log("Not connected", log: _log, type: .default)
      
      return;
    }
    
    let command = kAppConnectCmd + "=\(radioSerial) " + kHolePunchPort + "=\(String(holePunchPort))"
    sendCommand(command)
  }
  /// Disconnect users
  ///
  /// - Parameter radioSerial:        a radio serial number
  ///
  public func sendDisconnectUsersMessageToServer(radioSerial: String) {
    
    guard _isConnected else {
      
      os_log("Not connected", log: _log, type: .default)
      
      return;
    }
    // send the command
    sendCommand(kDisconnectUsersCmd + "=\(radioSerial)" )
  }
  /// Test connection
  ///
  /// - Parameter serial:             a radio serial number
  ///
  public func sendTestConnection(radioSerial: String) {
    
    guard _isConnected else {
      
      os_log("Not connected", log: _log, type: .default)
      
      return;
    }
    // send the command
    sendCommand(kTestCmd + "=\(radioSerial)" )
  }

  // ------------------------------------------------------------------------------
  // MARK: - Parser methods
  //     called by socket(:didReadData:withTag:), executes on the socketQ
  
  // ------------------------------------------------------------------------------
  // MARK: - First Level Parser
  
  /// Parse a received WanServer message
  ///
  /// - Parameter text:         the entire message
  ///
  internal func parseMsg(_ text: String) {
    
    let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // find the space & get the primary msgType
    let spaceIndex = msg.index(of: " ")!
    let msgType = String(msg[..<spaceIndex])
    
    // everything past the msgType is in the remainder
    let remainderIndex = msg.index(after: spaceIndex)
    let remainder = String(msg[remainderIndex...])
    
    // Check for unknown Message Types
    guard let token = Token(rawValue: msgType)  else {
      
      // unknown Message Type, log it and ignore the message
      os_log("Unknown message: %{public}@", log: _log, type: .default, msg)
      
      return
    }
    // which primary message type?
    switch token {
    
    case .application:
      parseApplication(remainder)
   
    case .radio:
      parseRadio(remainder)
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Second Level Parsers
  
  /// Parse a received "application" message
  ///
  /// - Parameter msg:        the message (after the primary type)
  ///
  internal func parseApplication(_ msg: String) {
    
    // find the space & get the secondary msgType
    let spaceIndex = msg.index(of: " ")!
    let msgType = String(msg[..<spaceIndex])
    
    // everything past the msgType is in the remainder
    let remainderIndex = msg.index(after: spaceIndex)
    let remainder = String(msg[remainderIndex...])
    
    // Check for unknown Message Types
    guard let token = ApplicationToken(rawValue: msgType)  else {
      
      // unknown Message Type, log it and ignore the message
      os_log("Unknown WanServer Application token: %{public}@", log: _log, type: .default, msg)
      
      return
    }
    // which secondary message type?
    switch token {
    
    case .info:
      parseApplicationInfo(remainder.keyValuesArray())
    
    case .registrationInvalid:
      parseRegistrationInvalid(remainder)
    
    case .userSettings:
      parseUserSettings(remainder.keyValuesArray())
    }
  }
  /// Parse a received "radio" message
  ///
  /// - Parameter msg:        the message (after the primary type)
  ///
  internal func parseRadio(_ msg: String) {
    
    // find the space & get the secondary msgType
    guard let spaceIndex = msg.index(of: " ") else {
      // only one word/command
      // example: "radio list" when no remote radio is registered with the server
      // TODO: do not handle it for now
      return
    }
    let msgType = String(msg[..<spaceIndex])
    
    // everything past the secondary msgType is in the remainder
    let remainderIndex = msg.index(after: spaceIndex)
    let remainder = String(msg[remainderIndex...])
    
    // Check for unknown Message Types
    guard let token = RadioToken(rawValue: msgType)  else {
      
      // unknown Message Type, log it and ignore the message
      os_log("Unknown WanServer Radio token: %{public}@", log: _log, type: .default, msg)
      
      return
    }
    // which secondary message type?
    switch token {
    
    case .connectReady:
      parseRadioConnectReady(remainder.keyValuesArray())
    
    case .list:
      parseRadioList(remainder)
    
    case .testConnection:
      parseTestConnectionResults(remainder.keyValuesArray())
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Third Level Parsers
  
  /// Parse Application properties
  ///
  /// - Parameter properties:         a KeyValuesArray
  ///
  private func parseApplicationInfo(_ properties: KeyValuesArray) {
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = ApplicationInfoToken(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        os_log("Unknown WanServer Info token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
      
      case .publicIp:
        willChangeValue(forKey: "sslClientPublicIp")
        _sslClientPublicIp = property.value
        didChangeValue(forKey: "sslClientPublicIp")
      }
    }
  }
  /// Respond to an Invalid registration
  ///
  /// - Parameter msg:                the message text
  ///
  private func parseRegistrationInvalid(_ msg: String) {
    
    os_log("%{public}@", log: _log, type: .default, msg)
    
  }
  /// Parse User properties
  ///
  /// - Parameter properties:         a KeyValuesArray
  ///
  private func parseUserSettings(_ properties: KeyValuesArray) {
    
    var callsign = ""
    var firstName = ""
    var lastName = ""
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = ApplicationUserSettingsToken(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
//        _api.log.msg("Unknown token - \(property.key)", level: .warning, function: #function, file: #file, line: #line)
        
        os_log("Unknown WanServer UserSettings token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
      
      case .callsign:
        callsign = property.value
      
      case .firstName:
        firstName = property.value
      
      case .lastName:
        lastName = property.value
      }
    }
    
    let userSettings = WanUserSettings(callsign: callsign, firstName: firstName, lastName: lastName)
    
    // delegate call
    _delegate?.wanUserSettings(userSettings)
  }
  /// Parse Radio properties
  ///
  /// - Parameter properties:         a KeyValuesArray
  ///
  private func parseRadioConnectReady(_ properties: KeyValuesArray) {
    
    var handle = ""
    var serial = ""
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = RadioConnectReadyToken(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        os_log("Unknown Radio Connect token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
      
      case .handle:
        handle = property.value
      
      case .serial:
        serial = property.value
      }
    }
    
    if handle != "" && serial != "" {
      
      _delegate?.wanRadioConnectReady(handle: handle, serial: serial)
    }
  }
  /// Parse a list of Radios
  ///
  /// - Parameter msg:        the list
  ///
  private func parseRadioList(_ msg: String) {
    
    // several radios are possible
    // separate list into its components
    let radioMessages = msg.components(separatedBy: "|")
    
    var wanRadioList = [RadioParameters]()
    
    for message in radioMessages where message != "" {
      
      // create a minimal RadioParameters with now as "lastSeen"
      let radio = RadioParameters()
      
      var publicTlsPortToUse = -1
      var publicUdpPortToUse = -1
      var isPortForwardOn = false
      var publicTlsPort = -1
      var publicUdpPort = -1
      var publicUpnpTlsPort = -1
      var publicUpnpUdpPort = -1
      
      let properties = message.keyValuesArray()
      
      // process each key/value pair, <key=value>
      for property in properties {
        
        // Check for Unknown token
        guard let token = RadioListToken(rawValue: property.key)  else {
          // unknown Token, log it and ignore this token
          os_log("Unknown Radio List token - %{public}@", log: _log, type: .default, property.key)
          
          continue
        }
        
        // Known tokens, in alphabetical order
        switch token {
        case .callsign:
          radio.callsign = property.value
        case .inUseIp:
          radio.inUseIp = property.value
        case .inUseHost:
          radio.inUseHost = property.value
        case .lastSeen:
          let dateFormatter = DateFormatter()
          // date format is like: 2/6/2018_5:20:16_AM
          dateFormatter.dateFormat = "M/d/yyy_H:mm:ss_a"
          
          guard let date = dateFormatter.date(from: property.value.lowercased()) else {
            os_log("LastSeen date mismatched format: %{public}@", log: _log, type: .error, property.value)
            
            break
          }
          // use date constant here
          radio.lastSeen = date
        case .maxLicensedVersion:
          radio.maxLicensedVersion = property.value
        case .model:
          radio.model = property.value
        case .publicIp:
          radio.ipAddress = property.value
        case .publicTlsPort:
          publicTlsPort = property.value.iValue()
        case .publicUdpPort:
          publicUdpPort = property.value.iValue()
        case .publicUpnpTlsPort:
          publicUpnpTlsPort = property.value.iValue()
        case .publicUpnpUdpPort:
          publicUpnpUdpPort = property.value.iValue()
        case .requiresAdditionalLicense:
          radio.requiresAdditionalLicense = property.value
        case .radioLicenseId:
          radio.radioLicenseId = property.value
        case .radioName:
          radio.name = property.value
        case .serial:
          radio.serialNumber = property.value
        case .status:
          radio.status = property.value
        case .upnpSupported:
          radio.upnpSupported = property.value.bValue()
        case .version:
          radio.firmwareVersion = property.value
        }
      }
      
      // now continue to fill the radio parameters
      // favor using the manually defined forwarded ports if they are defined
      if (publicTlsPort != -1 && publicUdpPort != -1) {
        publicTlsPortToUse = publicTlsPort
        publicUdpPortToUse = publicUdpPort
        isPortForwardOn = true;
      } else if (radio.upnpSupported) {
        publicTlsPortToUse = publicUpnpTlsPort
        publicUdpPortToUse = publicUpnpUdpPort
        isPortForwardOn = false
      }
      
      if ( !radio.upnpSupported && !isPortForwardOn ) {
        /* This will require extra negotiation that chooses
         * a port for both sides to try
         */
        //TODO: We also need to check the NAT for preserve_ports coming from radio here
        // if the NAT DOES NOT preserve ports then we can't do hole punch
        radio.requiresHolePunch = true
      }
      radio.publicTlsPort = publicTlsPortToUse
      radio.publicUdpPort = publicUdpPortToUse
      radio.isPortForwardOn = isPortForwardOn
      if let localAddr = _tlsSocket.localHost {
        radio.localInterfaceIP = localAddr
      }
      
      wanRadioList.append(radio)
    }
    // delegate call
    _delegate?.wanRadioListReceived(wanRadioList: wanRadioList)
  }
  /// Parse a Test Connection result
  ///
  /// - Parameter properties:         a KeyValuesArray
  ///
  private func parseTestConnectionResults(_ properties: KeyValuesArray) {
    
    var results = WanTestConnectionResults()
    
    // process each key/value pair, <key=value>
    for property in properties {
      
      // Check for Unknown token
      guard let token = RadioTestConnectionResultsToken(rawValue: property.key)  else {
        
        // unknown Token, log it and ignore this token
        os_log("Unknown WanServer TestConnection token - %{public}@", log: _log, type: .default, property.key)
        
        continue
      }
      
      // Known tokens, in alphabetical order
      switch token {
      case .forwardTcpPortWorking:
        results.forwardTcpPortWorking = property.value.bValue()
      case .forwardUdpPortWorking:
        results.forwardUdpPortWorking = property.value.bValue()
      case .natSupportsHolePunch:
        results.natSupportsHolePunch = property.value.bValue()
      case .radioSerial:
        results.radioSerial = property.value
      case .upnpTcpPortWorking:
        results.upnpTcpPortWorking = property.value.bValue()
      case .upnpUdpPortWorking:
        results.upnpUdpPortWorking = property.value.bValue()
      }
    }
    // call delegate
    _delegate?.wanTestConnectionResultsReceived(results: results)
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Read the next data block (with an indefinite timeout)
  ///
  private func readNext() {
    
    _tlsSocket.readData(to: GCDAsyncSocket.lfData(), withTimeout: -1, tag: 0)
  }
  /// Begin pinging the server
  ///
  private func startPinging() {
    
    // create the timer's dispatch source
    _pingTimer = DispatchSource.makeTimerSource(flags: [.strict], queue: _pingQ)
    
    // Set timer to start in 5 seconds and repeat every 10 seconds with 100 millisecond leeway
    _pingTimer?.schedule(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(5), repeating: .seconds(10), leeway: .milliseconds(100))      // Every 10 seconds +/- 100ms
    
    // set the event handler
    _pingTimer?.setEventHandler { [ unowned self] in
      
      // send another Ping
      self.sendCommand(self.kPingServerCmd)
    }
    // start the timer
    _pingTimer?.resume()
  }
  /// Stop pinging the server
  ///
  private func stopPinging() {
    
    // stop the Timer (if any)
    _pingTimer?.cancel();
  }
  /// Send a command to the server
  ///
  /// - Parameter cmd:                command text
  ///
  private func sendCommand(_ cmd: String) {
    
    let command = cmd + "\n"
    _tlsSocket.write(command.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withTimeout: -1, tag: 0)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - GCDAsyncSocket Delegate methods
  //      Note: all are called on the _socketQ
  
  /// Called when the TCP/IP connection has been disconnected
  ///
  /// - Parameters:
  ///   - sock:             the disconnected socket
  ///   - err:              the error
  ///
  @objc public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
    
    // Disconnected
    let error = (err == nil ? "" : "with error = " + err!.localizedDescription)
    os_log("WAN Server: %{public}@ on port: %{public}@ disconnected %{public}@", log: _log, type: err != nil ? .default : .info, _currentHost, _currentPort, error)
    

    stopPinging()
    
    _isConnected = false
    _currentHost = ""
    _currentPort = 0
  }
  /// Called after the TCP/IP connection has been established
  ///
  /// - Parameters:
  ///   - sock:               the socket
  ///   - host:               the host
  ///   - port:               the port
  ///
  @objc public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
    
    // Connected, save the ip & port
    _currentHost = sock.connectedHost ?? ""
    _currentPort = sock.connectedPort
    
    os_log("WAN Server: %{public}@ on port: %{public}d", log: _log, type: .info, _currentHost, _currentPort)
    
    // start server TLS connection
    var tlsSettings = [String : NSObject]()
    tlsSettings[kCFStreamSSLPeerName as String] = _hostName as NSObject
    _tlsSocket.startTLS(tlsSettings)
    
    // start pinging
    if _ping { startPinging() }
    
    _isConnected = true
  }
  /// Called when data has been read from the TCP/IP connection
  ///
  /// - Parameters:
  ///   - sock:                 the socket data was received on
  ///   - data:                 the Data
  ///   - tag:                  the Tag associated with this receipt
  ///
  @objc public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
    
    // get the bytes that were read
    let msg = String(data: data, encoding: .ascii)!
    
    // trigger the next read
    readNext()
    
    // process the message
    parseMsg(msg)
  }
  /**
   * Called after the socket has successfully completed SSL/TLS negotiation.
   * This method is not called unless you use the provided startTLS method.
   *
   * If a SSL/TLS negotiation fails (invalid certificate, etc) then the socket will immediately close,
   * and the socketDidDisconnect:withError: delegate method will be called with the specific SSL error code.
   **/
  /// Called after the socket has successfully completed SSL/TLS negotiation
  ///
  /// - Parameter sock:           the socket
  ///
  @objc public func socketDidSecure(_ sock: GCDAsyncSocket) {
    
    // starting the communication with the server over TLS
    let command = kAppRegisterCmd + "=\(_appName) " + kPlatform + "=\(_platform) " + kToken + "=\(_token)"
    
    os_log("Start TLS dialogue with WAN Server", log: _log, type: .info)
    
    sendCommand(command)
    
    // start reading
    readNext()
  }
}

// --------------------------------------------------------------------------------
// MARK: - Wan Class extensions
//              - Synchronized private properties
//              - Public properties
//              - WanServer tokens
// --------------------------------------------------------------------------------

extension WanServer {

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties - with synchronization
  
  // listed in alphabetical order
  
  private var _hostName: String {
    get { return _objectQ.sync { __hostName } }
    set { _objectQ.sync(flags: .barrier) { __hostName = newValue } } }
  
  private var _hostPort: Int {
    get { return _objectQ.sync { __hostPort } }
    set { _objectQ.sync(flags: .barrier) { __hostPort = newValue } } }
  
  private var _isConnected: Bool {
    get { return _objectQ.sync { __isConnected } }
    set { _objectQ.sync(flags: .barrier) { __isConnected = newValue } } }
  
  private var _sslClientPublicIp: String {
    get { return _objectQ.sync { __sslClientPublicIp } }
    set { _objectQ.sync(flags: .barrier) { __sslClientPublicIp = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant
  
  @objc dynamic public var hostName: String {
    return _hostName }
  
  @objc dynamic public var hostPort: Int {
    return _hostPort }
  
  @objc dynamic public var isConnected: Bool {
    return _isConnected }
  
  @objc dynamic public var sslClientPublicIp: String {
    return _sslClientPublicIp }
  
  // ----------------------------------------------------------------------------
  // MARK: - WanServer Tokens
  
  private enum Token: String {
    case application
    case radio
  }
  
  private enum ApplicationToken: String {
    case info
    case registrationInvalid        = "registration_invalid"
    case userSettings               = "user_settings"
  }
  
  private enum ApplicationInfoToken: String {
    case publicIp                   = "public_ip"
  }
  
  private enum ApplicationUserSettingsToken: String {
    case callsign
    case firstName                  = "first_name"
    case lastName                   = "last_name"
  }
  
  private enum RadioToken: String {
    case connectReady               = "connect_ready"
    case list
    case testConnection             = "test_connection"
  }
  
  private enum RadioConnectReadyToken: String {
    case handle
    case serial
  }
  
  private enum RadioListToken: String {
    case callsign
    case inUseIp                    = "inuseip"
    case inUseHost                  = "inusehost"
    case lastSeen                   = "last_seen"
    case maxLicensedVersion         = "max_licensed_version"
    case model
    case publicIp                   = "public_ip"
    case publicTlsPort              = "public_tls_port"
    case publicUdpPort              = "public_udp_port"
    case publicUpnpTlsPort          = "public_upnp_tls_port"
    case publicUpnpUdpPort          = "public_upnp_udp_port"
    case requiresAdditionalLicense  = "requires_additional_license"
    case radioLicenseId             = "radio_license_id"
    case radioName                  = "radio_name"
    case serial
    case status
    case upnpSupported              = "upnp_supported"
    case version
  }
  
  private enum RadioTestConnectionResultsToken: String {
    case forwardTcpPortWorking      = "forward_tcp_port_working"
    case forwardUdpPortWorking      = "forward_udp_port_working"
    case natSupportsHolePunch       = "nat_supports_hole_punch"
    case radioSerial                = "radio_serial"
    case upnpTcpPortWorking         = "upnp_tcp_port_working"
    case upnpUdpPortWorking         = "upnp_udp_port_working"
  }
}
