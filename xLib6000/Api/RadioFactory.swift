//
//  RadioFactory.swift
//  CommonCode
//
//  Created by Douglas Adams on 5/13/15
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

/// RadioFactory implementation
///
///      listens for the udp broadcasts announcing the presence of a Flex-6000
///      Radio, reports changes to the list of available radios
///
public final class RadioFactory             : NSObject, GCDAsyncUdpSocketDelegate {
  
  typealias IpAddress                       = String                        // dotted decimal form

  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var availableRadios: [RadioParameters] {
    get { return _radiosQ.sync { _availableRadios } }
    set { _radiosQ.sync(flags: .barrier) { _availableRadios = newValue } } }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _udpSocket                    : GCDAsyncUdpSocket?            // socket to receive broadcasts
  private var _timeoutTimer                 : DispatchSourceTimer!          // timer fired every "checkInterval"
  
  // GCD Queues
  private let _discoveryQ                   = DispatchQueue(label: "RadioFactory" + ".discoveryQ")
  private var _timerQ                       = DispatchQueue(label: "RadioFactory" + ".timerQ")
  private let _radiosQ                      = DispatchQueue(label: "RadioFactory" + ".radiosQ", attributes: .concurrent)

  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS -----
  //
  private var _availableRadios              = [RadioParameters]()           // Array of Radio Parameters
  //
  // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS -----

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a RadioFactory
  ///
  /// - Parameters:
  ///   - discoveryPort:        port number
  ///   - checkInterval:        how often to check
  ///   - notSeenInterval:      timeout interval
  ///
  public init(discoveryPort: UInt16 = 4992, checkInterval: TimeInterval = 1.0, notSeenInterval: TimeInterval = 3.0) {
    
    super.init()
    
    // create a Udp socket
    _udpSocket = GCDAsyncUdpSocket( delegate: self, delegateQueue: _discoveryQ )
    
    // if created
    if let sock = _udpSocket {
      
      // set socket options
      sock.setPreferIPv4()
      sock.setIPv6Enabled(false)
      
      // enable port reuse (allow multiple apps to use same port)
      do {
        try sock.enableReusePort(true)
        
      } catch let error as NSError {
        fatalError("Port reuse not enabled: \(error.localizedDescription)")
      }
      
      // bind the socket to the Flex Discovery Port
      do {
        try sock.bind(toPort: discoveryPort)
      }
      catch let error as NSError {
        fatalError("Bind to port error: \(error.localizedDescription)")
      }
      
      do {
        
        // attempt to start receiving
        try sock.beginReceiving()
        
        // create the timer's dispatch source
        _timeoutTimer = DispatchSource.makeTimerSource(flags: [.strict], queue: _timerQ)
        
        // Set timer with 100 millisecond leeway
        _timeoutTimer.schedule(deadline: DispatchTime.now(), repeating: checkInterval, leeway: .milliseconds(100))      // Every second +/- 10%
        
        // set the event handler
        _timeoutTimer.setEventHandler { [ unowned self] in
          
          var deleteList = [Int]()
          
          // check the timestamps of the UDPBroadcasts
          for (i, params) in self.availableRadios.enumerated() {
            
            // is it past expiration?
            if params.lastSeen.timeIntervalSinceNow < -notSeenInterval {
              
              // YES, add to the delete list
              deleteList.append(i)
            }
          }
          // are there any deletions?
          if deleteList.count > 0 {
            
            // YES, remove the Radio(s)
            for index in deleteList.reversed() {
              
              self.availableRadios.remove(at: index)
            }
            // send the updated list of radios to all observers
            NC.post(.radiosAvailable, object: self.availableRadios as Any?)
          }
        }
        
      } catch let error as NSError {
        fatalError("Begin receiving error: \(error.localizedDescription)")
      }
      // start the timer
      _timeoutTimer.resume()
    }
  }
  
  deinit {
    _timeoutTimer?.cancel()
    
    _udpSocket?.close()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Pause the collection of UDP broadcasts
  ///
  public func pause() {
  
    if let sock = _udpSocket {
      
      // pause receiving UDP broadcasts
      sock.pauseReceiving()
      
      // pause the timer
      _timeoutTimer.suspend()
    }
  }
  /// Resume the collection of UDP broadcasts
  ///
  public func resume() {
    
    if let sock = _udpSocket {
      
      // restart receiving UDP broadcasts
      try! sock.beginReceiving()
      
      // restart the timer
      _timeoutTimer.resume()
    }
  }
  /// send a Notification containing a list of current radios
  ///
  public func updateAvailableRadios() {
    
    // send the current list of radios to all observers
    NC.post(.radiosAvailable, object: self.availableRadios as Any?)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - GCDAsyncUdp delegate method
  
  /// The Socket received data
  ///
  ///   GCDAsyncUdpSocket delegate method, executes on the udpReceiveQ
  ///
  /// - Parameters:
  ///   - sock:           the GCDAsyncUdpSocket
  ///   - data:           the Data received
  ///   - address:        the Address of the sender
  ///   - filterContext:  the FilterContext
  ///
  @objc public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
    var knownRadio = false
    
    // VITA encoded Discovery packet?
    guard let vita = Vita.decodeFrom(data: data) else { return }
    
    // parse the packet to obtain a RadioParameters (updates the timestamp)
    guard let discoveredRadio = Vita.parseDiscovery(vita) else { return }
    
    // is it already in the availableRadios array? ( == compares serialNumbers )
    for (i, radio) in availableRadios.enumerated() where radio == discoveredRadio {

      let previousStatus = availableRadios[i].status
      
      // YES, update the existing entry
      availableRadios[i] = discoveredRadio
      
      // indicate it was a known radio
      knownRadio = true
      
      // has a known Radio's Status changed?
      if knownRadio && previousStatus != discoveredRadio.status {

        // YES, send the updated array of radio dictionaries to all observers
        NC.post(.radiosAvailable, object: availableRadios as Any?)
      }
    }
    // Is it a known radio?
    if knownRadio == false {
      
      // NO, add it to the array
      availableRadios.append(discoveredRadio)
      
      // send the updated array of radio dictionaries to all observers
      NC.post(.radiosAvailable, object: availableRadios as Any?)
    }
  }
}
