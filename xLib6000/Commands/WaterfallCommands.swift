//
//  WaterfallCommands.swift
//  xLib6000
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Waterfall Class extensions
//              - Static command prefix properties
//              - Dynamic public properties that send Commands to the Radio
// --------------------------------------------------------------------------------

extension Waterfall {
  
  static let kSetCmd                        = "display panafall set "       // Command prefixes
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods - Command helper methods
  
  /// Set a Waterfall property on the Radio
  ///
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func waterfallCmd(_ token: Token, _ value: Any) {
    
    Api.sharedInstance.send(Waterfall.kSetCmd + "\(id.hex) " + token.rawValue + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties - KVO compliant, that send Commands to the Radio (hardware)
  
  // listed in alphabetical order
  @objc dynamic public var autoBlackEnabled: Bool {
    get { return _autoBlackEnabled }
    set { if _autoBlackEnabled != newValue { _autoBlackEnabled = newValue ; waterfallCmd( .autoBlackEnabled, newValue.asNumber()) } } }
  
  @objc dynamic public var blackLevel: Int {
    get { return _blackLevel }
    set { if _blackLevel != newValue { _blackLevel = newValue ; waterfallCmd( .blackLevel, newValue) } } }
  
  @objc dynamic public var colorGain: Int {
    get { return _colorGain }
    set { if _colorGain != newValue { _colorGain = newValue ; waterfallCmd( .colorGain, newValue) } } }
  
  @objc dynamic public var gradientIndex: Int {
    get { return _gradientIndex }
    set { if _gradientIndex != newValue { _gradientIndex = newValue ; waterfallCmd( .gradientIndex, newValue) } } }
  
  @objc dynamic public var lineDuration: Int {
    get { return _lineDuration }
    set { if _lineDuration != newValue { _lineDuration = newValue ; waterfallCmd( .lineDuration, newValue) } } }
}
