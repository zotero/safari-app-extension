//
//  JSUtilities.swift
//  Lucidchart
//
//  Created by Joseph Slinker on 1/23/18.
//  Copyright © 2018 Lucid Software. All rights reserved.
//
//  Modified by Adomas Venckauskas on 06/09/2019.
//  Copyright © 2019 Corporation for Digital Scholarship. All rights reserved.
//

import Foundation
import JavaScriptCore

class JSUtilities: NSObject {
	
	private static var intervals: [Int: Timer] = [:]
	
	class func provideToContext(context: JSContext) {
		let setInterval: @convention(block) (Any) -> (Int) = { (any: Any) in
			return self.setInterval(repeats: true, args: JSContext.currentArguments() as! [JavaScriptCore.JSValue])
		}
		context.setObject(setInterval, forKeyedSubscript: "setInterval" as NSString)
		
		let setTimeout: @convention(block) (Any) -> (Int) = { (any: Any) in
			return self.setInterval(repeats: false, args: JSContext.currentArguments() as! [JavaScriptCore.JSValue])
		}
		context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)
		
		let clearInterval: @convention(block) (JavaScriptCore.JSValue) -> () = { (value: JavaScriptCore.JSValue) in
			self.clearInterval(tag: Int(value.toInt32()))
		}
		context.setObject(clearInterval, forKeyedSubscript: "clearInterval" as NSString)
		context.setObject(clearInterval, forKeyedSubscript: "clearTimeout" as NSString)
		
		// Base64 encoding/decoding functionality
		let atob: @convention(block) (String) -> String = { (encodedString: String) in
			guard let data = Data(base64Encoded: encodedString, options: .ignoreUnknownCharacters) else {
				return ""
			}
			// Create a binary string where each character represents a byte
			var result = ""
			for byte in data {
				result.append(Character(UnicodeScalar(byte)))
			}
			return result
		}
		context.setObject(atob, forKeyedSubscript: "atob" as NSString)
		
		let btoa: @convention(block) (String) -> String = { (binaryString: String) in
			// Create a Data object where each byte is the ASCII value of each character
			var bytes = [UInt8]()
			for char in binaryString {
				guard let ascii = char.asciiValue else {
					// JavaScript's btoa throws an exception for non-ASCII characters
					let context = JSContext.current()
					context?.exception = JSValue(newErrorFromMessage: "The string to be encoded contains characters outside of the Latin1 range.", in: context)
					return ""
				}
				bytes.append(ascii)
			}
			let data = Data(bytes)
			return data.base64EncodedString()
		}
		context.setObject(btoa, forKeyedSubscript: "btoa" as NSString)
	}
	
	private class func setInterval(repeats: Bool, args: [JavaScriptCore.JSValue]) -> Int {
		var args = args
		let function = args.removeFirst()
		var interval = 0.0
		if (args.count > 0) {
			interval = args.removeFirst().toDouble() / 1000
		}
		let tag = UUID().hashValue
		
		let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { (timer) in
			function.call(withArguments: [])
		}
		self.intervals[tag] = timer
		return tag
	}
	
	private class func clearInterval(tag: Int) {
		self.intervals[tag]?.invalidate()
		self.intervals[tag] = nil
	}
}
