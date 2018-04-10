//
//  UdpManager.swift
//  CommonCode
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - UdpManager delegate protocol
//
// --------------------------------------------------------------------------------

protocol UdpManagerDelegate                 : class {
  
  // if any of theses are not needed, implement a stub in the delegate that does nothing
  
  func udpError(_ message: String)                                          // report a UDP error
  func udpState(bound: Bool, port: UInt16, error: String)                   // report a UDP state change
  
  func udpStreamHandler(_ vita: Vita)
}

// ------------------------------------------------------------------------------
// MARK: - UDP Manager Class implementation
//
//      manages all Udp communication between the API and the Radio (hardware)
//
// ------------------------------------------------------------------------------

final class UdpManager                      : NSObject, GCDAsyncUdpSocketDelegate {

  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kUdpSendPort                   : UInt16 = 4991

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private weak var _delegate                : UdpManagerDelegate?           // class to receive UDP data
  private var _parameters                   : RadioParameters?              // Struct of Radio parameters
  private var _udpReceiveQ                  : DispatchQueue!                // serial GCD Queue for inbound UDP traffic
  private var _udpRegisterQ                 : DispatchQueue!                // serial GCD Queue for registration
  private var _udpSocket                    : GCDAsyncUdpSocket!            // socket for Vita UDP data
  private var _udpSuccessfulRegistration    = false
  private var _udpBound                     = false
  private var _udpRcvPort                   : UInt16 = 0                    // actual Vita port number
  private var _udpSendIP                    = ""                            // radio IP address (destination for send)
  private var _udpSendPort                  : UInt16 = kUdpSendPort

  private let kPingCmd                      = "client ping handle"
  private let kPingDelay                    : UInt32 = 50
  private let kMaxBindAttempts              = 20
  private let kRegisterCmd                  = "client udp_register handle"
  private let kRegistrationDelay            : UInt32 = 50_000

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a UdpManager
  ///
  /// - Parameters:
  ///   - udpReceiveQ:        a serial Q for Udp receive activity
  ///   - udpSendQ:           a serial Q for Udp send activity
  ///   - delegate:           a delegate for Udp activity
  ///   - udpPort:            a port number
  ///   - enableBroadcast:    whether to allow Broadcasts
  ///
  init(udpReceiveQ: DispatchQueue, udpRegisterQ: DispatchQueue, delegate: UdpManagerDelegate, udpRcvPort: UInt16 = 4991) {
    
    _udpReceiveQ = udpReceiveQ
    _udpRegisterQ = udpRegisterQ
    _delegate = delegate
    _udpRcvPort = udpRcvPort
    
    super.init()
    
    // get a socket
    _udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: _udpReceiveQ)
    _udpSocket.setIPv4Enabled(true)
    _udpSocket.setIPv6Enabled(false)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Send message encoded as Data to the Radio (on the current ip & port)
  ///
  /// - Parameters:
  ///   - data:               a Data
  ///
  func sendData(_ data: Data) {
    
    // send the Data on the outbound port
    _udpSocket.send(data, toHost: _udpSendIP, port: _udpSendPort, withTimeout: -1, tag: 0)
  }
  /// Bind to the UDP Port
  ///
  /// - Parameters:
  ///   - radioParameters:    a RadioParameters struct
  ///   - isWan:              Wan enabled
  ///   - clientHandle:       handle
  ///
  func bind(radioParameters: RadioParameters, isWan: Bool, clientHandle: String = "") {
    
    var success               = false
    var tmpPort               : UInt16 = 0
    var tries                 = kMaxBindAttempts
    
    // is this a Wan connection?
    if (isWan) {
      
      // YES, do we need a "hole punch"?
      if (radioParameters.requiresHolePunch) {
        
        // YES,
        tmpPort = UInt16(radioParameters.negotiatedHolePunchPort)
        _udpSendPort = UInt16(radioParameters.negotiatedHolePunchPort)
        
        // if hole punch port is occupied fail imediately
        tries = 1
        
      } else {
        
        // NO, start from the Vita Default port number
        tmpPort = _udpRcvPort
        _udpSendPort = UInt16(radioParameters.publicUdpPort)
      }
      
    } else {
      
      // NO, start from the Vita Default port number
      tmpPort = _udpRcvPort
    }
    // Find a UDP port to receive on, scan from the default Port Number up looking for an available port
    for _ in 0..<tries {
      
      do {
        try _udpSocket.bind(toPort: tmpPort)
        
        success = true
        
      } catch let error {
        
        // We didn't get the port we wanted
        _delegate?.udpError("Unable to bind to UDP port \(tmpPort) - \(error.localizedDescription)")
        
        // try the next Port Number
        tmpPort += 1
      }
      if success { break }
    }
    // capture the number of the actual port in use
    _udpRcvPort = tmpPort
    
    // save the ip address
    _udpSendIP = radioParameters.ipAddress
    
    // change the state
    _delegate?.udpState(bound: success, port: _udpRcvPort, error: success ? "" : "Unable to bind")
    
    _udpBound = true
    
    // if a Wan connection, register
    if isWan { register(clientHandle: clientHandle) }
  }
  /// Begin receiving UDP data
  ///
  func beginReceiving() {
    
    do {
      // Begin receiving
      try _udpSocket.beginReceiving()
      
    } catch let error {
      // read error
      _delegate?.udpError("beginReceiving error - \(error.localizedDescription)")
    }
  }
  /// Unbind from the UDP port
  ///
  func unbind() {
    
    _udpBound = false
    
    // tell the receive socket to close
    _udpSocket.close()
    
    // notify the delegate
    _delegate?.udpState(bound: false, port: 0, error: "")
  }
  /// Register UDP client handle and start pinger
  ///
  /// - Parameters:
  ///   - clientHandle:       our client handle
  ///
  private func register(clientHandle: String) {
    
    guard clientHandle != "" else {
      // should not happen
      _delegate?.udpError("No client handle in register UDP")
      return
    }
    // register & keep open the router (on a background queue)
    _udpRegisterQ.async { [unowned self] in
      
      // until successful Registration
      while self._udpSocket != nil && !self._udpSuccessfulRegistration && self._udpBound {
        
        // send a Registration command
        let cmd = self.kRegisterCmd + "=0x" + clientHandle
        self.sendData(cmd.data(using: String.Encoding.ascii, allowLossyConversion: false)!)
        
        // pause
        usleep(self.kRegistrationDelay)
      }
      // as long as connected after Registration
      while self._udpSocket != nil && self._udpBound {
        
        // We must maintain the NAT rule in the local router
        // so we have to send traffic every once in a while
        
        // send a Ping command
        let cmd = self.kPingCmd + "=0x" + clientHandle
        self.sendData(cmd.data(using: String.Encoding.ascii, allowLossyConversion: false)!)
        
        // pause
        sleep(self.kPingDelay)
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - GCDAsyncUdpSocket Protocol methods methods
  //            executes on the udpReceiveQ
  
  /// Called when data has been read from the UDP connection
  ///
  /// - Parameters:
  ///   - sock:               the receiving socket
  ///   - data:               the data received
  ///   - address:            the Host address
  ///   - filterContext:      a filter context (if any)
  ///
  @objc func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
    
    if let vita = Vita.decodeFrom(data: data) {
      
      // TODO: Packet statistics - received, dropped
      
      // ensure the packet has our OUI
      guard vita.oui == Vita.kFlexOui  else { return }

      // we got a VITA packet which means registration was successful
      _udpSuccessfulRegistration = true

      switch vita.packetType {
        
      case .ifDataWithStream, .extDataWithStream:
        
        // stream of data, pass it to the delegate
        _delegate?.udpStreamHandler(vita)

      case .ifData, .extData, .ifContext, .extContext:
        
        // error, pass it to the delegate
        _delegate?.udpError("Unexpected packetType - \(vita.packetType.rawValue)")
      }
      
    } else {
      
      // pass the error to the delegate
      _delegate?.udpError("Invalid packet received")
    }
  }
}
