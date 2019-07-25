//
//  BandSettingCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 4/6/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Command extension

extension BandSetting {
  
  // ----------------------------------------------------------------------------
  // MARK: - Class methods that send Commands
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Instance methods that send Commands
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Properties (KVO compliant) that send Commands
  
  // FIXME: Commands ???
  
  @objc dynamic public var accTxEnabled: Bool {
    get { return _accTxEnabled }
    set { if _accTxEnabled != newValue { _accTxEnabled = newValue  } } }
  
  @objc dynamic public var accTxReqEnabled: Bool {
    get { return _accTxReqEnabled }
    set { if _accTxReqEnabled != newValue { _accTxReqEnabled = newValue  } } }
  
  @objc dynamic public var bandName: String {
    get { return _bandName }
    set { if _bandName != newValue { _bandName = newValue  } } }
  
  @objc dynamic public var hwAlcEnabled: Bool {
    get { return _hwAlcEnabled }
    set { if _hwAlcEnabled != newValue { _hwAlcEnabled = newValue  } } }
  
  @objc dynamic public var inhibit: Bool {
    get { return _inhibit }
    set { if _inhibit != newValue { _inhibit = newValue  } } }
  
  @objc dynamic public var rcaTxReqEnabled: Bool {
    get { return _rcaTxReqEnabled }
    set { if _rcaTxReqEnabled != newValue { _rcaTxReqEnabled = newValue  } } }
  
  @objc dynamic public var rfPower: Int {
    get { return _rfPower }
    set { if _rfPower != newValue { _rfPower = newValue  } } }
  
  @objc dynamic public var tunePower: Int {
    get { return _tunePower }
    set { if _tunePower != newValue { _tunePower = newValue  } } }

  @objc dynamic public var tx1Enabled: Bool {
    get { return _tx1Enabled }
    set { if _tx1Enabled != newValue { _tx1Enabled = newValue  } } }
  
  @objc dynamic public var tx2Enabled: Bool {
    get { return _tx2Enabled }
    set { if _tx2Enabled != newValue { _tx2Enabled = newValue  } } }
  
  @objc dynamic public var tx3Enabled: Bool {
    get { return _tx3Enabled }
    set { if _tx3Enabled != newValue { _tx3Enabled = newValue  } } }
}
