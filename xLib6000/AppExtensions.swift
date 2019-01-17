//
//  Extensions.swift
//  xLib6000
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Date

public extension Date {
  
  /// Create a Date/Time in the local time zone
  ///
  /// - Returns: a DateTime string
  ///
  func currentTimeZoneDate() -> String {
    let dtf = DateFormatter()
    dtf.timeZone = TimeZone.current
    dtf.dateFormat = "yyyy-MM-dd HH:mm:ss"
    
    return dtf.string(from: self)
  }
}

// ----------------------------------------------------------------------------
// MARK: - NotificationCenter

public extension NotificationCenter {
  
  /// post a Notification by Name
  ///
  /// - Parameters:
  ///   - notification:   Notification Name
  ///   - object:         associated object
  ///
  public class func post(_ name: String, object: Any?) {
    
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: object)
    
  }
  /// post a Notification by Type
  ///
  /// - Parameters:
  ///   - notification:   Notification Type
  ///   - object:         associated object
  ///
  public class func post(_ notification: NotificationType, object: Any?) {
    
    NotificationCenter.default.post(name: Notification.Name(rawValue: notification.rawValue), object: object)
    
  }
  /// setup a Notification Observer by Name
  ///
  /// - Parameters:
  ///   - observer:       the object receiving Notifications
  ///   - selector:       a Selector to receive the Notification
  ///   - type:           Notification name
  ///   - object:         associated object (if any)
  ///
  public class func makeObserver(_ observer: Any, with selector: Selector, of name: String, object: Any? = nil) {
    
    NotificationCenter.default.addObserver(observer, selector: selector, name: NSNotification.Name(rawValue: name), object: object)
  }
  /// setup a Notification Observer by Type
  ///
  /// - Parameters:
  ///   - observer:       the object receiving Notifications
  ///   - selector:       a Selector to receive the Notification
  ///   - type:           Notification type
  ///   - object:         associated object (if any)
  ///
  public class func makeObserver(_ observer: Any, with selector: Selector, of type: NotificationType, object: Any? = nil) {
    
    NotificationCenter.default.addObserver(observer, selector: selector, name: NSNotification.Name(rawValue: type.rawValue), object: object)
  }
  /// remove a Notification Observer by Type
  ///
  /// - Parameters:
  ///   - observer:       the object receiving Notifications
  ///   - type:           Notification type
  ///   - object:         associated object (if any)
  ///
  public class func deleteObserver(_ observer: Any, of type: NotificationType, object: Any?) {
    
    NotificationCenter.default.removeObserver(observer, name: NSNotification.Name(rawValue: type.rawValue), object: object)
  }
}

// ----------------------------------------------------------------------------
// MARK: - Sequence Type

public extension Sequence {
  
  /// Find an element in an array
  ///
  /// - Parameters:
  ///   - match:      comparison closure
  /// - Returns:      the element (or nil)
  ///
  func findElement(_ match:(Iterator.Element)->Bool) -> Iterator.Element? {
    
    for element in self where match(element) {
      return element
    }
    return nil
  }
}

// ----------------------------------------------------------------------------
// MARK: - String

public typealias KeyValuesArray = [(key:String, value:String)]
public typealias ValuesArray = [String]

public extension String {
  
  /// Convert a Mhz string to an Hz Int
  ///
  /// - Returns:      the Int equivalent
  ///
  var mhzToHz : Int {
    return Int( (Double(self) ?? 0) * 1_000_000 )
  }
  /// Return the Integer value (or 0 if invalid)
  ///
  /// - Returns:      the Int equivalent
  ///
  var iValue : Int {
    return Int(self) ?? 0
  }
  /// Return the Bool value (or false if invalid)
  ///
  /// - Returns:      a Bool equivalent
  ///
  var bValue : Bool {
    return (Int(self) ?? 0) == 1 ? true : false
  }
  /// Return the Bool value (or false if invalid)
  ///
  /// - Returns:      a Bool equivalent
  ///
  var tValue : Bool {
    return self.lowercased() == "true" ? true : false
  }
  /// Return the Float value (or 0 if invalid)
  ///
  /// - Returns:      a Float equivalent
  ///
  var fValue : Float {
    return Float(self) ?? 0
  }
  /// Return the Double value (or 0 if invalid)
  ///
  /// - Returns:      a Double equivalent
  ///
  var dValue : Double {
    return Double(self) ?? 0
  }
  /// Replace spaces with a specified value
  ///
  /// - Parameters:
  ///   - value:      the String to replace spaces
  /// - Returns:      the adjusted String
  ///
  func replacingSpaces(with value: String = "\u{007F}") -> String {
    return self.replacingOccurrences(of: " ", with: value)
  }
  /// Parse a String of <key=value>'s separated by the given Delimiter
  ///
  /// - Parameters:
  ///   - delimiter:          the delimiter between key values (defaults to space)
  ///   - keysToLower:        convert all Keys to lower case (defaults to YES)
  ///   - valuesToLower:      convert all values to lower case (defaults to NO)
  /// - Returns:              a KeyValues array
  ///
  public func keyValuesArray(delimiter: String = " ", keysToLower: Bool = true, valuesToLower: Bool = false) -> KeyValuesArray {
    var kvArray = KeyValuesArray()
    
    // split it into an array of <key=value> values
    let keyAndValues = self.components(separatedBy: delimiter)
    
    for index in 0..<keyAndValues.count {
      // separate each entry into a Key and a Value
      var kv = keyAndValues[index].components(separatedBy: "=")
      
      // when "delimiter" is last character there will be an empty entry, don't include it
      if kv[0] != "" {
        
        // if no "=", set value to empty String (helps with strings with a prefix to KeyValues)
        // make sure there are no whitespaces before or after the entries
        if kv.count == 1 {
          
          // remove leading & trailing whitespace
          kvArray.append( (kv[0].trimmingCharacters(in: NSCharacterSet.whitespaces),"") )
        }
        if kv.count == 2 {
          
          // lowercase as needed
          if keysToLower { kv[0] = kv[0].lowercased() }
          if valuesToLower { kv[1] = kv[1].lowercased() }
          
          // remove leading & trailing whitespace
          kvArray.append( (kv[0].trimmingCharacters(in: NSCharacterSet.whitespaces),kv[1].trimmingCharacters(in: NSCharacterSet.whitespaces)) )
        }
      }
    }
    return kvArray
  }
  /// Parse a String of <value>'s separated by the given Delimiter
  ///
  /// - Parameters:
  ///   - delimiter:          the delimiter between values (defaults to space)
  ///   - valuesToLower:      convert all values to lower case (defaults to NO)
  /// - Returns:              a values array
  ///
  func valuesArray(delimiter: String = " ", valuesToLower: Bool = false) -> ValuesArray {
    
    // split it into an array of <value> values, lowercase as needed
    return valuesToLower ? self.components(separatedBy: delimiter).map {$0.lowercased()} : self.components(separatedBy: delimiter)
  }
  /// Replace spaces and equal signs in a CWX Macro with alternate characters
  ///
  /// - Returns:      the String after processing
  ///
  func fix(spaceReplacement: String = "\u{007F}", equalsReplacement: String = "*") -> String {
    var newString: String = ""
    var quotes = false
    
    // We could have spaces inside quotes, so we have to convert them to something else for key/value parsing.
    // We could also have an equal sign '=' (for Prosign BT) inside the quotes, so we're converting to a '*' so that the split on "="
    // will still work.  This will prevent the character '*' from being stored in a macro.  Using the ascii byte for '=' will not work.
    for char in self {
      if char == "\"" {
        quotes = !quotes
        
      } else if char == " " && quotes {
        newString += spaceReplacement
        
      } else if char == "=" && quotes {
        newString += equalsReplacement
        
      } else {
        newString.append(char)
      }
    }
    return newString
  }
  /// Undo any changes made to a Cwx Macro string by the fix method    ///
  ///
  /// - Returns:          the String after undoing the fixString changes
  ///
  func unfix(spaceReplacement: String = "\u{007F}", equalsReplacement: String = "*") -> String {
    var newString: String = ""
    
    for char in self {
      
      if char == Character(spaceReplacement) {
        newString += " "
        
      } else if char == Character(equalsReplacement) {
        newString += "="
        
      } else {
        newString.append(char)
      }
    }
    return newString
  }
  /// Check if a String is a valid IP4 address
  ///
  /// - Returns:          the result of the check as Bool
  ///
  func isValidIP4() -> Bool {
    
    // check for 4 values separated by period
    let parts = self.components(separatedBy: ".")
    
    // convert each value to an Int
    #if swift(>=4.1)
      let nums = parts.compactMap { Int($0) }
    #else
      let nums = parts.flatMap { Int($0) }
    #endif
    
    // must have 4 values containing 4 numbers & 0 <= number < 256
    return parts.count == 4 && nums.count == 4 && nums.filter { $0 >= 0 && $0 < 256}.count == 4
  }
}

// ----------------------------------------------------------------------------
// MARK: - Bool

public extension Bool {
  
  /// Return 1 / 0 for true / false Booleans
  ///
  /// - Returns:      a String
  ///
  var asInt : Int {
    return (self ? 1 : 0)
  }
  /// Return "1" / "0" for true / false Booleans
  ///
  /// - Returns:      a String
  ///
  var asNumber : String {
    return (self ? "1" : "0")
  }
  /// Return "True" / "False" Strings for true / false Booleans
  ///
  /// - Returns:      a String
  ///
  var asString : String {
    return (self ? "True" : "False")
  }
  /// Return "T" / "F" Strings for true / false Booleans
  ///
  /// - Returns:      a String
  ///
  var asLetter : String {
    return (self ? "T" : "F")
  }
  /// Return "on" / "off" Strings for true / false Booleans
  ///
  /// - Returns:      a String
  ///
  var asOnOff : String {
    return (self ? "on" : "off")
  }
  /// Return "PASS" / "FAIL" Strings for true / false Booleans
  ///
  /// - Returns:      a String
  ///
  var asPassFail : String  {
    return self == true ? "PASS" : "FAIL"
  }
  /// Return "YES" / "NO" Strings for true / false Booleans
  ///
  /// - Returns:      a String
  ///
  var asYesNo : String {
    return self == true ? "YES" : "NO"
  }
}

// ----------------------------------------------------------------------------
// MARK: - Int

public extension Int {
  
  /// Convert an Int Hz value to a Mhz string
  ///
  /// - Returns:      the String equivalent
  ///
  var hzToMhz : String {
    
    // convert to a String with up to 2 leading & with 6 trailing places
    return String(format: "%02.6f", Float(self) / 1_000_000.0)
  }
  /// Determine if a value is between two other values (inclusive)
  ///
  /// - Parameters:
  ///   - value1:     low value (may be + or -)
  ///   - value2:     high value (may be + or -)
  /// - Returns:      true - self within two values
  ///
  func within(_ value1: Int, _ value2: Int) -> Bool {
    
    return (self >= value1) && (self <= value2)
  }
  
  /// Force a value to be between two other values (inclusive)
  ///
  /// - Parameters:
  ///   - value1:     the Minimum
  ///   - value2:     the Maximum
  /// - Returns:      the coerced value
  ///
  func bound(_ value1: Int, _ value2: Int) -> Int {
    let newValue = self < value1 ? value1 : self
    return newValue > value2 ? value2 : newValue
  }
}

// ----------------------------------------------------------------------------
// MARK: - UInt32

public extension UInt32 {
  
  // convert a UInt32 to a hax String (defaults to "0xXXXXXXXX")
  func toHex(_ format: String = "0x%08X") -> String {
    
    return String(format: format, self)
  }
  
  // convert a UInt32 to a hex String (uppercase, leading zeros, 8 characters, 0x prefix)
  var hex: String { return String(format: "0x%08X", self) }
}

// ----------------------------------------------------------------------------
// MARK: - CGFloat

public extension CGFloat {
  
  /// Force a CGFloat to be within a min / max value range
  ///
  /// - Parameters:
  ///   - min:        min CGFloat value
  ///   - max:        max CGFloat value
  /// - Returns:      adjusted value
  ///
  func bracket(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
    
    var value = self
    if self < min { value = min }
    if self > max { value = max }
    return value
  }
  /// Create a CGFloat from a String
  ///
  /// - Parameters:
  ///   - string:     a String
  ///
  /// - Returns:      CGFloat value of String or 0
  ///
  init(_ string: String) {
    
    self = CGFloat(Float(string) ?? 0)
  }
  /// Format a String with the value of a CGFloat
  ///
  /// - Parameters:
  ///   - width:      number of digits before the decimal point
  ///   - precision:  number of digits after the decimal point
  ///   - divisor:    divisor
  /// - Returns:      a String representation of the CGFloat
  ///
  private func floatToString(width: Int, precision: Int, divisor: CGFloat) -> String {
    
    return String(format: "%\(width).\(precision)f", self / divisor)
  }
}

