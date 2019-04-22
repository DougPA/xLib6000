//
//  DiscoveredClient.swift
//  xLib6000
//
//  Created by Douglas Adams on 4/20/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Foundation

public final class DiscoveredClient                      : NSObject {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var handle               : ClientHandle
//  public var host                 : String
  public var id                   : UUID?
//  public var ip                   : String
  public var isAvailable          : Bool
  public var localPttEnabled      : Bool
  public var program              : String
  public var station              : String

  public init(handle: ClientHandle,
              host: String,
              id: UUID? = nil,
              ip: String,
              isAvailable: Bool = true,
              localPttEnabled: Bool = false,
              program: String,
              station: String )
  {
    self.handle = handle
//    self.host = host
    self.id = id
//    self.ip = ip
    self.isAvailable = isAvailable
    self.localPttEnabled = localPttEnabled
    self.program = program
    self.station = station
  }
}
