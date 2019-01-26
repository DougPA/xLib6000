//
//  Api.swift
//  CommonCode
//
//  Created by Douglas Adams on 12/27/17.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

// --------------------------------------------------------------------------------
// MARK: - API Class implementation
//
//      manages the connections to the Radio (hardware), responsible for the
//      creation / destruction of the Radio class (the object analog of the
//      Radio hardware)
//
// --------------------------------------------------------------------------------

import os

public final class Api                      : NSObject, TcpManagerDelegate, UdpManagerDelegate {
  
  public static let kId                     = "xLib6000"                    // API Name
  public static let kDomainId               = "net.k3tzr"                   // Domain name
  public static let kBundleIdentifier       = Api.kDomainId + "." + Api.kId
  public static let daxChannels             = ["None", "1", "2", "3", "4", "5", "6", "7", "8"]
  public static let daxIqChannels           = ["None", "1", "2", "3", "4"]

  static let kTcpTimeout                    = 0.5                           // seconds
  static let kNoError                       = "0"
  static let kControlMin                    = 0                             // control ranges
  static let kControlMax                    = 100
  static let kMinApfQ                       = 0
  static let kMaxApfQ                       = 33
  static let kNotInUse                      = "in_use=0"                    // removal indicators
  static let kRemoved                       = "removed"

  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  @objc dynamic public var radio            : Radio?                        // current Radio class

  public var availableRadios                : [RadioParameters] {           // Radios discovered
    return _radioFactory.availableRadios }
  public var delegate                       : ApiDelegate?                  // API delegate
  public var testerModeEnabled              = false                         // Library being used by xAPITester
  public var testerDelegate                 : ApiDelegate?                  // API delegate for xAPITester
  public var activeRadio                    : RadioParameters?              // Radio params
  public var pingerEnabled                  = true                          // Pinger enable
  public var isWan                          = false                         // Remote connection
  public var wanConnectionHandle            = ""                            // Wan connection handle
  public var connectionHandle               = ""                            // Status messages handle

  public private(set) var apiVersionMajor   = 0                             // numeric versions of Api firmware version
  public private(set) var apiVersionMinor   = 0
  public private(set) var radioVersionMajor = 0                             // numeric versions of Radio firmware version
  public private(set) var radioVersionMinor = 0

  public let kApiFirmwareSupport            = "2.4.9.x"                     // The Radio Firmware version supported by this API
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _log                          = OSLog(subsystem: kBundleIdentifier, category: "Api")
  private var _apiState                     : Api.NewState! {
    didSet { os_log("Api state == %{public}@", log: _log, type: .info, _apiState.rawValue) }
  }
  private var _tcp                          : TcpManager!                   // TCP connection class (commands)
  private var _udp                          : UdpManager!                   // UDP connection class (streams)
  private var _primaryCmdTypes              = [Api.Command]()               // Primary command types to be sent
  private var _secondaryCmdTypes            = [Api.Command]()               // Secondary command types to be sent
  private var _subscriptionCmdTypes         = [Api.Command]()               // Subscription command types to be sent
  
  private var _primaryCommands              = [CommandTuple]()              // Primary commands to be sent
  private var _secondaryCommands            = [CommandTuple]()              // Secondary commands to be sent
  private var _subscriptionCommands         = [CommandTuple]()              // Subscription commands to be sent
  private let _clientIpSemaphore            = DispatchSemaphore(value: 0)   // semaphore to signal that we have got the client ip

  // GCD Concurrent Queue
  private let _objectQ                      = DispatchQueue(label: Api.kId + ".objectQ", attributes: [.concurrent])

  // GCD Serial Queues
  private let _tcpReceiveQ                  = DispatchQueue(label: Api.kId + ".tcpReceiveQ", qos: .userInitiated)
  private let _tcpSendQ                     = DispatchQueue(label: Api.kId + ".tcpSendQ")
  private let _udpReceiveQ                  = DispatchQueue(label: Api.kId + ".udpReceiveQ", qos: .userInitiated)
  private let _udpRegisterQ                 = DispatchQueue(label: Api.kId + ".udpRegisterQ", qos: .background)
  private let _pingQ                        = DispatchQueue(label: Api.kId + ".pingQ")
  private let _parseQ                       = DispatchQueue(label: Api.kId + ".parseQ", qos: .userInteractive)
  private let _workerQ                      = DispatchQueue(label: Api.kId + ".workerQ")

  private var _radioFactory                 = RadioFactory()                // Radio Factory class
  private var _pinger                       : Pinger?                       // Pinger class
  private var _clientName                   = ""
  private var _isGui                        = true                          // GUI enable
  private var _lowBW                        = false                         // low bandwidth connect

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var _localIP                      = "0.0.0.0"                     // client IP for radio
  private var _localUDPPort                 : UInt16 = 0                    // bound UDP port
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----

  // ----------------------------------------------------------------------------
  // MARK: - Singleton
  
  /// Provide access to the API singleton
  ///
  @objc dynamic public static var sharedInstance = Api()
  
  private override init() {
    super.init()
    
    // "private" prevents others from calling init()
    
    // initialize a Manager for the TCP Command stream
    _tcp = TcpManager(tcpReceiveQ: _tcpReceiveQ, tcpSendQ: _tcpSendQ, delegate: self, timeout: Api.kTcpTimeout)
    
    // initialize a Manager for the UDP Data Streams
    _udp = UdpManager(udpReceiveQ: _udpReceiveQ, udpRegisterQ: _udpRegisterQ, delegate: self)
    
    // set the initial State
    _apiState = .disconnected
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Connect to a Radio
  ///
  /// - Parameters:
  ///     - selectedRadio:        a RadioParameters struct for the desired Radio
  ///     - primaryCmdTypes:      array of "primary" command types (defaults to .all)
  ///     - secondaryCmdTYpes:    array of "secondary" command types (defaults to .all)
  ///     - subscriptionCmdTypes: array of "subscription" commandtypes (defaults to .all)
  ///     - metersToSubscribe:    array of meter short type (defaults to .all)
  /// - Returns:                  Success / Failure
  ///
  public func connect(_ selectedRadio: RadioParameters,
                      clientName: String,
                      isGui: Bool = true,
                      isWan: Bool = false,
                      wanHandle: String = "",
                      primaryCmdTypes: [Api.Command] = [.allPrimary],
                      secondaryCmdTypes: [Api.Command] = [.allSecondary],
                      subscriptionCmdTypes: [Api.Command] = [.allSubscription] ) -> Bool {

    // must be in the Ready state to connect
    guard _apiState == .disconnected else { return false }
    
    _clientName = clientName
    _isGui = isGui
    self.isWan = isWan
    wanConnectionHandle = wanHandle
    
    // Create a Radio class
    radio = Radio(api: self, queue: _objectQ)
    
    activeRadio = selectedRadio
    
    // save the Command types
    _primaryCmdTypes = primaryCmdTypes
    _secondaryCmdTypes = secondaryCmdTypes
    _subscriptionCmdTypes = subscriptionCmdTypes
    
    // start a connection to the Radio
    if _tcp.connect(radioParameters: selectedRadio, isWan: isWan) {
      
      // pause listening for Discovery broadcasts
      //          _radioFactory.pause()
      
      // check the versions
      checkFirmware()
      
      return true
    }
    // returns sucess if active
    return false
  }
  /// Shutdown the active Radio
  ///
  /// - Parameter reason:         a reason code
  ///
  public func shutdown(reason: DisconnectReason = .normal) {
    
    // stop pinging (if active)
    if _pinger != nil {
      _pinger = nil
      
      os_log("Pinger stopped", log: _log, type: .info)
    }
    // the radio (if any) will be removed, inform observers
    if activeRadio != nil { NC.post(.radioWillBeRemoved, object: radio as Any?) }
    
    if _apiState != .disconnected {
      // disconnect TCP
      _tcp.disconnect()
      
      // unbind and close udp
      _udp.unbind()
    }
    
    // the radio (if any)) has been removed, inform observers
    if activeRadio != nil { NC.post(.radioHasBeenRemoved, object: nil) }

    // remove the Radio
    activeRadio = nil
    
    // FIXME: possible race on setting / reading radio
    
    radio = nil
  }
  /// Send a command to the Radio (hardware)
  ///
  /// - Parameters:
  ///   - command:        a Command String
  ///   - flag:           use "D"iagnostic form
  ///   - callback:       a callback function (if any)
  ///
  public func send(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil) {
    
    // tell the TcpManager to send the command
    let seqNumber = _tcp.send(command, diagnostic: flag)

    // register to be notified when reply received
    delegate?.addReplyHandler( String(seqNumber), replyTuple: (replyTo: callback, command: command) )
    
    // pass it to xAPITester (if present)
    testerDelegate?.addReplyHandler( String(seqNumber), replyTuple: (replyTo: callback, command: command) )
  }
  /// Send a command to the Radio (hardware), first check that a Radio is connected
  ///
  /// - Parameters:
  ///   - command:        a Command String
  ///   - flag:           use "D"iagnostic form
  ///   - callback:       a callback function (if any)
  /// - Returns:          Success / Failure
  ///
  public func sendWithCheck(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil) -> Bool {
    
    // abort if no connection
    guard _tcp.isConnected else { return false }
    
    // send
    send(command, diagnostic: flag, replyTo: callback)

    return true
  }
  /// Send a Vita packet to the Radio
  ///
  /// - Parameters:
  ///   - data:       a Vita-49 packet as Data
  ///
  public func sendVitaData(_ data: Data?) {
    
    // if data present
    if let dataToSend = data {
      
      // send it (no validity checks are performed)
      _udp.sendData(dataToSend)
    }
  }
  /// Send the collection of commands to configure the connection
  ///
  public func sendCommands() {
    
    // setup commands
    _primaryCommands = setupCommands(_primaryCmdTypes)
    _subscriptionCommands = setupCommands(_subscriptionCmdTypes)
    _secondaryCommands = setupCommands(_secondaryCmdTypes)
    
    // send the initial commands
    sendCommandList(_primaryCommands)
    
    // send the subscription commands
    sendCommandList(_subscriptionCommands)
    
    // send the secondary commands
    sendCommandList(_secondaryCommands)
  }

  /// A Client has been connected
  ///
  func clientConnected() {

    // code to be executed after an IP Address has been obtained
    func connectionCompletion() {
      
      // send the initial commands
      sendCommands()
      
      // set the streaming UDP port
      if isWan {
        // Wan, establish a UDP port for the Data Streams
        _udp.bind(radioParameters: activeRadio!, isWan: true, clientHandle: connectionHandle)
        
      } else {
        // Local
        send(Api.Command.clientUdpPort.rawValue + "\(localUDPPort)")
      }
      // start pinging
      if pingerEnabled {
        
        let wanStatus = isWan ? "REMOTE" : "LOCAL"
        let p = (isWan ? activeRadio!.publicTlsPort : activeRadio!.port)
        os_log("Started pinging: %{public}@ @ %{public}@, port %{public}d (%{public}@)", log: _log, type: .info, activeRadio!.nickname, activeRadio!.publicIp, p, wanStatus)
        
        _pinger = Pinger(tcpManager: _tcp, pingQ: _pingQ)
      }
      // TCP & UDP connections established, inform observers
      NC.post(.clientDidConnect, object: activeRadio as Any?)
      
      _apiState = .clientConnected
    }

    // could this be a remote connection?
    if apiVersionMajor >= 2 {
      
      // YES, when connecting to a WAN radio, the public IP address of the connected
      // client must be obtained from the radio.  This value is used to determine
      // if audio streams from the radio are meant for this client.
      // (IsAudioStreamStatusForThisClient() checks for LocalIP)
      send("client ip", replyTo: clientIpReplyHandler)
      
      // take this off the socket receive queue
      _workerQ.async { [unowned self] in
        
        // wait for the response
        let time = DispatchTime.now() + DispatchTimeInterval.milliseconds(5000)
        _ = self._clientIpSemaphore.wait(timeout: time)
        
        // complete the connection
        connectionCompletion()
      }
      
    } else {
      
      // NO, use the ip of the local interface
      localIP = _tcp.interfaceIpAddress
      
      // complete the connection
      connectionCompletion()
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
    
  /// Determine if the Radio (hardware) Firmware version is compatable with the API version
  ///
  /// - Parameters:
  ///   - selectedRadio:      a RadioParameters struct
  ///
  private func checkFirmware() {
    
    // separate the parts of each version
    let apiVersionParts = kApiFirmwareSupport.components(separatedBy: ".")
    let radioVersionParts = activeRadio!.firmwareVersion.components(separatedBy: ".")
    
    // compare the versions
    if apiVersionParts[0] != radioVersionParts[0] || apiVersionParts[1] != radioVersionParts[1] || apiVersionParts[2] != radioVersionParts[2] {
    
      os_log("Update needed, Radio version = %{public}@, API supports version = %{public}@", log: _log, type: .default, activeRadio!.firmwareVersion, kApiFirmwareSupport)
      
      NC.post(.updateRequired, object: kApiFirmwareSupport + "," + activeRadio!.firmwareVersion)
    }
    // set integer numbers for major and minor for fast comparision
    apiVersionMajor = Int(apiVersionParts[0]) ?? 0
    apiVersionMinor = Int(apiVersionParts[1]) ?? 0
    radioVersionMajor = Int(radioVersionParts[0]) ?? 0
    radioVersionMinor = Int(radioVersionParts[1]) ?? 0
  }
  /// Send a command list to the Radio
  ///
  /// - Parameters:
  ///   - commands:       an array of CommandTuple
  ///
  private func sendCommandList(_ commands: [CommandTuple]) {
    
    // send the commands to the Radio (hardware)
    commands.forEach { send($0.command, diagnostic: $0.diagnostic, replyTo: $0.replyHandler) }
  }
  ///
  ///     Note: commands will be in default order if one of the .all... values is passed
  ///             otherwise commands will be in the order found in the incoming array
  ///
  /// Populate a Commands array
  ///
  /// - Parameters:
  ///   - commands:       an array of Commands
  /// - Returns:          an array of CommandTuple
  ///
  private func setupCommands(_ commands: [Api.Command]) -> [(CommandTuple)] {
    var array = [(CommandTuple)]()
    
    // return immediately if none required
    if !commands.contains(.none) {
      
      // check for the "all..." cases
      var adjustedCommands = commands
      if commands.contains(.allPrimary) {                             // All Primary
        
        adjustedCommands = Api.Command.allPrimaryCommands()
        
      } else if commands.contains(.allSecondary) {                    // All Secondary
        
        adjustedCommands = Api.Command.allSecondaryCommands()
        
      } else if commands.contains(.allSubscription) {                 // All Subscription
        
        adjustedCommands = Api.Command.allSubscriptionCommands()
      }
      
      // add all the specified commands
      for command in adjustedCommands {
        
        switch command {
          
        case .setMtu:
          if radioVersionMajor == 2 && radioVersionMinor >= 3 {
            // the MTU command is only used for radio firmware versions >= 2.3.x
            array.append( (command.rawValue, false, nil) )
          }

        case .clientProgram:
          array.append( (command.rawValue + _clientName, false, delegate?.defaultReplyHandler) )
          
        case .clientLowBW:
          if _lowBW { array.append( (command.rawValue, false, nil) ) }
          
        case .meterList:
          array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
          
        case .info:
          array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
          
        case .version:
          array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
          
        case .antList:
          array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
          
        case .micList:
          array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
          
        case .clientGui:
          if _isGui { array.append( (command.rawValue, false, nil) ) }
          
        case .none, .allPrimary, .allSecondary, .allSubscription:   // should never occur
          break
          
        default:
          array.append( (command.rawValue, false, nil) )
        }
      }
    }
    return array
  }
  /// Reply handler for the "client ip" command
  ///
  /// - Parameters:
  ///   - command:                a Command string
  ///   - seqNum:                 the Command's sequence number
  ///   - responseValue:          the response contained in the Reply to the Command
  ///   - reply:                  the descriptive text contained in the Reply to the Command
  ///
  private func clientIpReplyHandler(_ command: String, seqNum: String, responseValue: String, reply: String) {
    
    // was an error code returned?
    if responseValue == Api.kNoError {
      
      // NO, the reply value is the IP address
      localIP = reply.isValidIP4() ? reply : "0.0.0.0"

    } else {

      // YES, use the ip of the local interface
      localIP = _tcp.interfaceIpAddress
    }
    // signal completion of the "client ip" command
    _clientIpSemaphore.signal()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Notification methods
  
  /// Add Notifications
  ///
  private func addNotifications() {
    
    // Pinging Started
    NC.makeObserver(self, with: #selector(tcpPingStarted(_:)), of: .tcpPingStarted, object: nil)
    
    // Ping Timeout
    NC.makeObserver(self, with: #selector(tcpPingTimeout(_:)), of: .tcpPingTimeout, object: nil)
  }
  /// Process .tcpPingStarted Notification
  ///
  /// - Parameters:
  ///   - note:       a Notification instance
  ///
  @objc private func tcpPingStarted(_ note: Notification) {
    
    os_log("Pinger started", log: _log, type: .info)
  }
  /// Process .tcpPingTimeout Notification
  ///
  /// - Parameters:
  ///   - note:       a Notification instance
  ///
  @objc private func tcpPingTimeout(_ note: Notification) {
    
    os_log("Pinger timeout", log: _log, type: .error)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - TcpManagerDelegate methods
  //    arrives on the tcpReceiveQ

  /// Process a received message
  ///
  /// - Parameter msg:        text of the message
  ///
  func receivedMessage(_ msg: String) {
    
    // is it a non-empty message?
    if msg.count > 1 {
      
      // YES, pass it to the parser (async on the parseQ)
      _parseQ.async { [ unowned self ] in
        self.delegate?.receivedMessage( String(msg.dropLast()) )

        // pass it to xAPITester (if present)
        self.testerDelegate?.receivedMessage( String(msg.dropLast()) )
      }
    }
  }
  /// Process a sent message
  ///
  /// - Parameter msg:         text of the message
  ///
  func sentMessage(_ msg: String) {
    
    delegate?.sentMessage( String(msg.dropLast()) )
    
    // pass it to xAPITester (if present)
    testerDelegate?.sentMessage( String(msg.dropLast()) )
  }
  /// Respond to a TCP Connection/Disconnection event
  ///
  /// - Parameters:
  ///   - connected:  state of connection
  ///   - host:       host address
  ///   - port:       port number
  ///   - error:      error message
  ///
  func tcpState(connected: Bool, host: String, port: UInt16, error: String) {
    
    // connected?
    if connected {
      
      // log it
      let wanStatus = isWan ? "REMOTE" : "LOCAL"
      let guiStatus = _isGui ? "(GUI) " : ""
      os_log("TCP connected to %{public}@ @ %{public}@, port %{public}d %{public}@(%{public}@)", log: _log, type: .info, activeRadio!.nickname, host, port, guiStatus, wanStatus)
      
      // YES, set state
      _apiState = .tcpConnected
      
      // a tcp connection has been established, inform observers
      NC.post(.tcpDidConnect, object: nil)
      
      _tcp.readNext()
      
      if isWan {
        let cmd = "wan validate handle=" + wanConnectionHandle // TODO: + "\n"
        send(cmd, replyTo: nil)
        
        os_log("Wan validate handle: %{public}@", log: _log, type: .info, wanConnectionHandle)
        
      } else {
        // insure that a UDP port was bound (for the Data Streams)
        guard _udp.bind(radioParameters: activeRadio!, isWan: isWan) else {
          
          // Bind failed, disconnect
          _tcp.disconnect()

          // the tcp connection was disconnected, inform observers
          NC.post(.tcpDidDisconnect, object: DisconnectReason.error(errorMessage: "Udp bind failure"))

          return
        }
      }
      // if another Gui client connected, disconnect it
      if activeRadio!.status == "In_Use" && _isGui {
        
        send("client disconnect")
        os_log("\"client disconnect\" sent", log: _log, type: .info)
        sleep(1)
      }

    } else {
      
      // NO, error?
      if error == "" {
        
        // the tcp connection was disconnected, inform observers
        NC.post(.tcpDidDisconnect, object: DisconnectReason.normal)

        os_log("Tcp Disconnected", log: _log, type: .info)
        
      } else {
        
        // YES, disconnect with error (don't keep the UDP port open as it won't be reused with a new connection)
        
        _udp.unbind()
        
        // the tcp connection was disconnected, inform observers
        NC.post(.tcpDidDisconnect, object: DisconnectReason.error(errorMessage: error))

        os_log("Tcp Disconnected with message = %{public}@", log: _log, type: .info, error)
      }

      _apiState = .disconnected
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - UdpManager delegate methods
  //    arrives on the udpReceiveQ
  
  /// Respond to a UDP Connection/Disconnection event
  ///
  /// - Parameters:
  ///   - bound:  state of binding
  ///   - port:   a port number
  ///   - error:  error message
  ///
  func udpState(bound : Bool, port: UInt16, error: String) {
    
    // bound?
    if bound {
      
      // YES, UDP (streams) connection established
      
      os_log("UDP bound to Port %{public}d", log: _log, type: .info, port)
      
      _apiState = .udpBound
      
      localUDPPort = port
      
      // a UDP port has been bound, inform observers
      NC.post(.udpDidBind, object: nil)
      
      // a UDP bind has been established
      _udp.beginReceiving()
      
      // if WAN connection reset the state to .clientConnected as the true connection state
      if isWan {
        
        _apiState = .clientConnected
      }
    } else {
    
    // TODO: should there be a udpUnbound state ?
    }
  }
  /// Receive a UDP Stream packet
  ///
  /// - Parameter vita: a Vita packet
  ///
  func udpStreamHandler(_ vitaPacket: Vita) {
    
    delegate?.vitaParser(vitaPacket)

    // pass it to xAPITester (if present)
    testerDelegate?.vitaParser(vitaPacket)
  }
}

// --------------------------------------------------------------------------------
// MARK: - Api Class extensions
//              - Public properties, no message to Radio
//              - Api enums
// --------------------------------------------------------------------------------

extension Api {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant (no message to Radio)
  
  public var localIP: String {
    get { return _objectQ.sync { _localIP } }
    set { _objectQ.sync(flags: .barrier) { _localIP = newValue } } }
  
  public var localUDPPort: UInt16 {
    get { return _objectQ.sync { _localUDPPort } }
    set { _objectQ.sync(flags: .barrier) { _localUDPPort = newValue } } }

  // ----------------------------------------------------------------------------
  // MARK: - Api enums
  
  ///
  ///     Note: The "clientUdpPort" command must be sent AFTER the actual Udp port number has been determined.
  ///           The default port number may already be in use by another application.
  ///
  public enum Command: String, Equatable {
    
    // GROUP A: none of this group should be included in one of the command sets
    case none
    case clientUdpPort                      = "client udpport "
    case allPrimary
    case allSecondary
    case allSubscription
    case clientIp                           = "client ip"
    
    // GROUP B: members of this group can be included in the command sets
    case antList                            = "ant list"
    case clientProgram                      = "client program "
    case clientDisconnect                   = "client disconnect"
    case clientGui                          = "client gui"
    case clientLowBW                        = "client low_bw_connect"
    case eqRx                               = "eq rxsc info"
    case eqTx                               = "eq txsc info"
    case info
    case meterList                          = "meter list"
    case micList                            = "mic list"
    case profileGlobal                      = "profile global info"
    case profileTx                          = "profile tx info"
    case profileMic                         = "profile mic info"
    case setMtu                             = "client set enforce_network_mtu=1 network_mtu=1500"
    case subAmplifier                       = "sub amplifier all"
    case subAudioStream                     = "sub audio_stream all"
    case subAtu                             = "sub atu all"
    case subCwx                             = "sub cwx all"
    case subDax                             = "sub dax all"
    case subDaxIq                           = "sub daxiq all"
    case subFoundation                      = "sub foundation all"
    case subGps                             = "sub gps all"
    case subMemories                        = "sub memories all"
    case subMeter                           = "sub meter all"
    case subPan                             = "sub pan all"
    case subRadio                           = "sub radio all"
    case subScu                             = "sub scu all"
    case subSlice                           = "sub slice all"
    case subTnf                             = "sub tnf all"
    case subTx                              = "sub tx all"
    case subUsbCable                        = "sub usb_cable all"
    case subXvtr                            = "sub xvtr all"
    case version
    
    // Note: Do not include GROUP A values in these return vales
    
    static func allPrimaryCommands() -> [Command] {
      return [.clientProgram, .clientLowBW, .clientGui]
    }
    static func allSecondaryCommands() -> [Command] {
      return [.setMtu, .info, .version, .antList, .micList, .profileGlobal,
              .profileTx, .profileMic, .eqRx, .eqTx]
    }
    static func allSubscriptionCommands() -> [Command] {
      return [.subRadio, .subTx, .subAtu, .subPan, .subMeter, .subSlice, .subTnf, .subGps,
              .subAudioStream, .subCwx, .subXvtr, .subMemories, .subDaxIq, .subDax,
              .subUsbCable, .subAmplifier, .subFoundation, .subScu]
    }
  }
    
  public enum MeterShortName : String {
    case codecOutput            = "codec"
    case microphoneAverage      = "mic"
    case microphoneOutput       = "sc_mic"
    case microphonePeak         = "micpeak"
    case postClipper            = "comppeak"
    case postFilter1            = "sc_filt_1"
    case postFilter2            = "sc_filt_2"
    case postGain               = "gain"
    case postRamp               = "aframp"
    case postSoftwareAlc        = "alc"
    case powerForward           = "fwdpwr"
    case powerReflected         = "refpwr"
    case preRamp                = "b4ramp"
    case preWaveAgc             = "pre_wave_agc"
    case preWaveShim            = "pre_wave"
    case signal24Khz            = "24khz"
    case signalPassband         = "level"
    case signalPostNrAnf        = "nr/anf"
    case signalPostAgc          = "agc+"
    case swr                    = "swr"
    case temperaturePa          = "patemp"
    case voltageAfterFuse       = "+13.8b"
    case voltageBeforeFuse      = "+13.8a"
    case voltageHwAlc           = "hwalc"

    public static func allMeters() -> [MeterShortName] {
      return [.codecOutput, .microphoneAverage, .microphoneOutput, .microphonePeak,
              .postClipper, .postFilter1, .postFilter2, .postGain, .postRamp, .postSoftwareAlc,
              .powerForward, .powerReflected, .preWaveAgc, .preWaveShim, .signal24Khz,
              .signalPassband, .signalPostNrAnf, .signalPostAgc, .swr, .temperaturePa,
              .voltageAfterFuse, .voltageBeforeFuse, .voltageHwAlc]
    }
  }
  
  public enum DisconnectReason: Equatable {
    public static func ==(lhs: Api.DisconnectReason, rhs: Api.DisconnectReason) -> Bool {
      
      switch (lhs, rhs) {
      case (.normal, .normal): return true
      case let (.error(l), .error(r)): return l == r
      default: return false
      }
    }
    case normal
    case error (errorMessage: String)
  }
  
  public enum NewState: String {
    case start
    case tcpConnected
    case udpBound
    case clientConnected
    case disconnected
    case update
  }

  // --------------------------------------------------------------------------------
  // MARK: - Type Alias (alphabetical)
  
  public typealias CommandTuple = (command: String, diagnostic: Bool, replyHandler: ReplyHandler?)
  
}
