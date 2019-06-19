//
//  Api.swift
//  CommonCode
//
//  Created by Douglas Adams on 12/27/17.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

/// API Class implementation
///
///      manages the connections to the Radio (hardware), responsible for the
///      creation / destruction of the Radio class (the object analog of the
///      Radio hardware)
///
public final class Api                      : NSObject, TcpManagerDelegate, UdpManagerDelegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  public enum Level : String {
    case debug        = "Debug"
    case info         = "Info"
    case warning      = "Warning"
    case error        = "Error"
  }

  
  public static let kId                     = "xLib6000"                    // API Name
  public static let kDomainId               = "net.k3tzr"                   // Domain name
  public static let kBundleIdentifier       = Api.kDomainId + "." + Api.kId
  public static let daxChannels             = ["None", "1", "2", "3", "4", "5", "6", "7", "8"]
  public static let daxIqChannels           = ["None", "1", "2", "3", "4"]
  public static let kNoError                = "0"

  static let kTcpTimeout                    = 0.5                           // seconds
  static let kControlMin                    = 0                             // control ranges
  static let kControlMax                    = 100
  static let kMinApfQ                       = 0
  static let kMaxApfQ                       = 33
  static let kNotInUse                      = "in_use=0"                    // removal indicators
  static let kRemoved                       = "removed"

  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  @objc dynamic public var radio            : Radio?                        // current Radio class
  public var apiState                       : Api.State! {
    didSet { log.msg( "Api state = \(apiState.rawValue)", level: .info, function: #function, file: #file, line: #line)}}

  public var discoveredRadios               : [DiscoveredRadio] {           // Radios discovered
    return _radioFactory.discoveredRadios }
  public var delegate                       : ApiDelegate?                  // API delegate
  public var testerModeEnabled              = false                         // Library being used by xAPITester
  public var testerDelegate                 : ApiDelegate?                  // API delegate for xAPITester
  public var activeRadio                    : DiscoveredRadio?              // Radio params
  public var pingerEnabled                  = true                          // Pinger enable
  public var isWan                          = false                         // Remote connection
  public var wanConnectionHandle            = ""                            // Wan connection handle
  public var connectionHandle               : UInt32?                       // Status messages handle
  public var log                            = Log.sharedInstance            // Logger

  // GCD Concurrent Queue
  public let objectQ                        = DispatchQueue(label: Api.kId + ".objectQ", attributes: [.concurrent])

  public private(set) var apiVersion        = Version("2.5.1.20190618")     // Api firmware version
  public private(set) var radioVersion      = Version()                     // Radio firmware version

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _tcp                          : TcpManager!                   // TCP connection class (commands)
  private var _udp                          : UdpManager!                   // UDP connection class (streams)
  private var _primaryCmdTypes              = [Api.Command]()               // Primary command types to be sent
  private var _secondaryCmdTypes            = [Api.Command]()               // Secondary command types to be sent
  private var _subscriptionCmdTypes         = [Api.Command]()               // Subscription command types to be sent
  
  private var _primaryCommands              = [CommandTuple]()              // Primary commands to be sent
  private var _secondaryCommands            = [CommandTuple]()              // Secondary commands to be sent
  private var _subscriptionCommands         = [CommandTuple]()              // Subscription commands to be sent
  private let _clientIpSemaphore            = DispatchSemaphore(value: 0)   // semaphore to signal that we have got the client ip
  

  // GCD Serial Queues
  private let _tcpReceiveQ                  = DispatchQueue(label: Api.kId + ".tcpReceiveQ")
  private let _tcpSendQ                     = DispatchQueue(label: Api.kId + ".tcpSendQ")
  private let _udpReceiveQ                  = DispatchQueue(label: Api.kId + ".udpReceiveQ", qos: .userInteractive)
  private let _udpRegisterQ                 = DispatchQueue(label: Api.kId + ".udpRegisterQ")
  private let _pingQ                        = DispatchQueue(label: Api.kId + ".pingQ")
  private let _parseQ                       = DispatchQueue(label: Api.kId + ".parseQ", qos: .userInteractive)
  private let _workerQ                      = DispatchQueue(label: Api.kId + ".workerQ")

  private var _radioFactory                 = RadioFactory()                // Radio Factory class
  private var _pinger                       : Pinger?                       // Pinger class
  private var _clientId                     : UUID?                         //
  private var _clientName                   = ""                            //
  private var _clientStation                = ""                            //
  private var _isGui                        = true                          // GUI enable
  private var _lowBW                        = false                         // low bandwidth connect

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
  //
  private var _localIP                      = "0.0.0.0"                     // client IP for radio
  private var _localUDPPort                 : UInt16 = 0                    // bound UDP port
  private var _guiClients                   = [Handle:GuiClient]()          // Dictionary of Gui Clients
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
    apiState = .disconnected
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods

  /// Connect to a Radio
  ///
  /// - Parameters:
  ///     - selectedRadio:        a DiscoveredRadio class for the desired Radio
  ///     - clientName:           the name of the Client using this library
  ///     - clientId:             a UUID String (if any)
  ///     - isGui:                whether this is a GUI connection
  ///     - isWan:                whether this is a Wan connection
  ///     - wanHandle:            Wan Handle (if any)
  ///     - primaryCmdTypes:      array of "primary" command types (defaults to .all)
  ///     - secondaryCmdTYpes:    array of "secondary" command types (defaults to .all)
  ///     - subscriptionCmdTypes: array of "subscription" commandtypes (defaults to .all)
  /// - Returns:                  Success / Failure
  ///
  public func connect(_ selectedRadio: DiscoveredRadio,
                      clientStation: String,
                      clientName: String,
                      clientId: UUID?,
                      isGui: Bool = true,
                      isWan: Bool = false,
                      wanHandle: String = "",
                      primaryCmdTypes: [Api.Command] = [.allPrimary],
                      secondaryCmdTypes: [Api.Command] = [.allSecondary],
                      subscriptionCmdTypes: [Api.Command] = [.allSubscription] ) -> Bool {

    // must be in the Disconnected state to connect
    guard apiState == .disconnected else { return false }
    
    _clientName = clientName
    _clientId = clientId
    _clientStation = clientStation
    _isGui = isGui
    self.isWan = isWan
    wanConnectionHandle = wanHandle
    
    // Create a Radio class
    radio = Radio(api: self, queue: objectQ)
    
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
      
      // send the initial commands
      sendCommands()
      
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
      
      log.msg("Pinger stopped", level: .info, function: #function, file: #file, line: #line)
    }
    // the radio (if any) will be removed, inform observers
    if activeRadio != nil { NC.post(.radioWillBeRemoved, object: radio as Any?) }
    
    if apiState != .disconnected {
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// A Client has been connected
  ///
  func clientConnected() {
    
      // set the streaming UDP port
      if isWan {
        // Wan, establish a UDP port for the Data Streams
        let _ = _udp.bind(radioParameters: activeRadio!, isWan: true, clientHandle: connectionHandle)
        
      } else {
        // Local
        send(Api.Command.clientUdpPort.rawValue + "\(localUDPPort)")
      }
      // start pinging
      if pingerEnabled {
        
        let wanStatus = isWan ? "REMOTE" : "LOCAL"
        let p = (isWan ? activeRadio!.publicTlsPort : activeRadio!.port)
        log.msg( "Started pinging: \(activeRadio!.nickname) @ \(activeRadio!.publicIp), port \(p) (\(wanStatus))", level: .info, function: #function, file: #file, line: #line)

        _pinger = Pinger(tcpManager: _tcp, pingQ: _pingQ)
      }
      // TCP & UDP connections established, inform observers
      NC.post(.clientDidConnect, object: activeRadio as Any?)
      
      apiState = .clientConnected
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
    
  /// Determine if the Radio (hardware) Firmware version is compatable with the API version
  ///
  /// - Parameters:
  ///   - selectedRadio:      a RadioParameters struct
  ///
  private func checkFirmware() {
    
    // create the Version structs
    radioVersion = Version(activeRadio!.firmwareVersion)
    // make sure they are valid
    // compare them
    if radioVersion < apiVersion {
      // Radio may need update
      log.msg("Radio firmware may need to be upgraded: Radio version = \(radioVersion.string), API supports version = \(apiVersion.shortString)", level: .warning, function: #function, file: #file, line: #line)
      
    } else if apiVersion < radioVersion {
      // Radio may need downgrade
      log.msg("Radio firmware must be downgraded: Radio version = \(radioVersion.string), API supports version = \(apiVersion.shortString)", level: .warning, function: #function, file: #file, line: #line)
      NC.post(.radioFirmwareDowngradeRequired, object: [apiVersion, radioVersion])
    }
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
      var adjustedCommands : [Api.Command]
      switch commands {
      case [.allPrimary]:       adjustedCommands = Api.Command.allPrimaryCommands()
      case [.allSecondary]:     adjustedCommands = Api.Command.allSecondaryCommands()
      case [.allSubscription]:  adjustedCommands = Api.Command.allSubscriptionCommands()
      default:                  adjustedCommands = commands
      }
      
      // add all the specified commands
      for command in adjustedCommands {
        
        switch command {
          
        // Conditionally send the following
        case .setMtu:
          if radioVersion.major == 2 && radioVersion.minor >= 3 {
            // the MTU command is only used for radio firmware versions >= 2.3.x
            array.append( (command.rawValue, false, nil) )
          }
          
        // Add parameters to the following
        case .clientProgram:  if _isGui { array.append( (command.rawValue + _clientName, false, nil) ) }
        case .clientStation:  if _isGui { array.append( (command.rawValue + _clientStation, false, nil) ) }
          
        //        case .clientLowBW:
        //          if _lowBW { array.append( (command.rawValue, false, nil) ) }
          
        // Capture the replies from the following
        case .meterList:    array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
        case .info:         array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
        case .version:      array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
        case .antList:      array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
        case .micList:      array.append( (command.rawValue, false, delegate?.defaultReplyHandler) )
        case .clientGui:    if _isGui { array.append( (command.rawValue + " " + (_clientId?.uuidString ?? ""), false, delegate?.defaultReplyHandler) ) }
        case .clientBind:   if !_isGui && _clientId != nil { array.append( (command.rawValue + " " + _clientId!.uuidString, false, nil) ) }
          
        // Ignore the following
        case .none, .allPrimary, .allSecondary, .allSubscription: break
          
        // All others
        default: array.append( (command.rawValue, false, nil) )
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
  // MARK: - TcpManagerDelegate methods

  /// Process a received message
  ///
  ///   TcpManagerDelegate method, arrives on the tcpReceiveQ
  ///   calls delegate methods on the parseQ
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
  ///   TcpManagerDelegate method, arrives on the tcpReceiveQ
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
  ///   TcpManagerDelegate method, arrives on the tcpReceiveQ
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
      log.msg( "TCP connected to \(activeRadio!.nickname) @ \(host), port \(port) \(guiStatus)(\(wanStatus)), radio version = \(activeRadio!.firmwareVersion)", level: .info, function: #function, file: #file, line: #line)

      // YES, set state
      apiState = .tcpConnected
      
      // a tcp connection has been established, inform observers
      NC.post(.tcpDidConnect, object: nil)
      
      _tcp.readNext()
      
      if isWan {
        let cmd = "wan validate handle=" + wanConnectionHandle // TODO: + "\n"
        send(cmd, replyTo: nil)
        
        log.msg( "Wan validate handle: \(wanConnectionHandle)", level: .info, function: #function, file: #file, line: #line)

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
        log.msg( "\"client disconnect\" sent", level: .info, function: #function, file: #file, line: #line)
        sleep(1)
      }

    } else {
      
      // NO, error?
      if error == "" {
        
        // the tcp connection was disconnected, inform observers
        NC.post(.tcpDidDisconnect, object: DisconnectReason.normal)

        log.msg( "Tcp Disconnected", level: .info, function: #function, file: #file, line: #line)

      } else {
        
        // YES, disconnect with error (don't keep the UDP port open as it won't be reused with a new connection)
        
        _udp.unbind()
        
        // the tcp connection was disconnected, inform observers
        NC.post(.tcpDidDisconnect, object: DisconnectReason.error(errorMessage: error))

       log.msg( "Tcp Disconnected with message = \(error)", level: .info, function: #function, file: #file, line: #line)
      }

      apiState = .disconnected
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - UdpManager delegate methods
  
  /// Respond to a UDP Connection/Disconnection event
  ///
  ///   UdpManager delegate method, arrives on the udpReceiveQ
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
      
      log.msg( "UDP bound to Port \(port)", level: .info, function: #function, file: #file, line: #line)

      apiState = .udpBound
      
      localUDPPort = port
      
      // a UDP port has been bound, inform observers
      NC.post(.udpDidBind, object: nil)
      
      // a UDP bind has been established
      _udp.beginReceiving()
      
      // if WAN connection reset the state to .clientConnected as the true connection state
      if isWan {
        
        apiState = .clientConnected
      }
    } else {
    
    // TODO: should there be a udpUnbound state ?
    }
  }
  /// Receive a UDP Stream packet
  ///
  ///   UdpManager delegate method, arrives on the udpReceiveQ
  ///
  /// - Parameter vita: a Vita packet
  ///
  func udpStreamHandler(_ vitaPacket: Vita) {
    
    delegate?.vitaParser(vitaPacket)

    // pass it to xAPITester (if present)
    testerDelegate?.vitaParser(vitaPacket)
  }
}

extension Api {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties (KVO compliant)
  
  public var guiClients: [Handle:GuiClient] {
    get { return objectQ.sync { _guiClients } }
    set { objectQ.sync(flags: .barrier) { _guiClients = newValue } } }
  
  public var localIP: String {
    get { return objectQ.sync { _localIP } }
    set { objectQ.sync(flags: .barrier) { _localIP = newValue } } }
  
  public var localUDPPort: UInt16 {
    get { return objectQ.sync { _localUDPPort } }
    set { objectQ.sync(flags: .barrier) { _localUDPPort = newValue } } }

  // ----------------------------------------------------------------------------
  // MARK: - Enums
  
  /// Commands
  ///
  ///     The "clientUdpPort" command must be sent AFTER the actual Udp port number has been determined.
  ///     The default port number may already be in use by another application.
  ///
  public enum Command: String, Equatable {
    
    // GROUP A: none of this group should be included in one of the command sets
    case none
    case allPrimary
    case allSecondary
    case allSubscription
    case clientUdpPort                      = "client udpport "
    case keepAliveEnabled                   = "keepalive enable"
    
    // GROUP B: members of this group can be included in the command sets
    case antList                            = "ant list"
    case clientBind                         = "client bind"
    case clientDisconnect                   = "client disconnect"
    case clientGui                          = "client gui"
    case clientIp                           = "client ip"
    case clientProgram                      = "client program "
//    case clientLowBW                        = "client low_bw_connect"
    case clientStation                      = "client station "
    case eqRx                               = "eq rxsc info"
    case eqTx                               = "eq txsc info"
    case info
    case meterList                          = "meter list"
    case micList                            = "mic list"
    case profileDisplay                     = "profile display info"
    case profileGlobal                      = "profile global info"
    case profileMic                         = "profile mic info"
    case profileTx                          = "profile tx info"
    case setMtu                             = "client set enforce_network_mtu=1 network_mtu=1500"
    case setReducedDaxBw                    = "client set send_reduced_bw_dax=1"
    case subAmplifier                       = "sub amplifier all"
    case subAudioStream                     = "sub audio_stream all"
    case subAtu                             = "sub atu all"
    case subClient                          = "sub client all"
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
    case subSpot                            = "sub spot all"
    case subTnf                             = "sub tnf all"
    case subTx                              = "sub tx all"
    case subUsbCable                        = "sub usb_cable all"
    case subXvtr                            = "sub xvtr all"
    case version
    
    // Note: Do not include GROUP A values in these return vales
    
    static func allPrimaryCommands() -> [Command] {
      return [.clientIp, .clientGui, .clientProgram, .clientStation, .clientBind, .info, .version, .antList, .micList, .profileGlobal, .profileTx, .profileMic, .profileDisplay]
    }
    static func allSubscriptionCommands() -> [Command] {
      return [.subClient, .subTx, .subAtu, .subAmplifier, .subMeter, .subPan, .subSlice, .subGps,
              .subAudioStream, .subCwx, .subXvtr, .subMemories, .subDaxIq, .subDax,
              .subUsbCable, .subTnf, .subSpot]
    }
    static func allSecondaryCommands() -> [Command] {
      return [.setMtu, .setReducedDaxBw, .clientStation]

    }
  }
    
  /// Meter names
  ///
  public enum MeterShortName : String, CaseIterable {
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
  }
  
  /// Disconnect reasons
  ///
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
  /// States
  ///
  public enum State: String {
    case start
    case tcpConnected
    case udpBound
    case clientConnected
    case disconnected
    case update
  }

  // --------------------------------------------------------------------------------
  // MARK: - Aliases
  
  /// Definition for a Command Tuple
  ///
  ///   command:        a Radio command String
  ///   diagnostic:     if true, send as a Diagnostic command
  ///   replyHandler:   method to process the reply (may be nil)
  ///
  public typealias CommandTuple = (command: String, diagnostic: Bool, replyHandler: ReplyHandler?)
  
}
