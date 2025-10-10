//
//  HTTP.swift
//  SafariExtension
//
//  Created by Adomas Venckauskas on 27/08/2019.
//  Copyright © 2019 Corporation for Digital Scholarship. All rights reserved.
//

import Foundation
import JavaScriptCore

enum HTTP {
	/// Perform a HTTP request.
	/// - parameter url: URL for the request.
	/// - parameter method: HTTP method of the request.
	/// - parameter headers: Optional HTTP headers for the request.
	/// - parameter body: Optional body data for request.
	/// - parameter timeout: Timeout interval of the request.
	/// - parameter completion: Completion block of request.
	/// - parameter response:
	/// 				0: statusCode: Response status code. Can be -1 if URL was not specified correctly
	///                         or -2 if Method was not specified.
	///				1: url (error message)
	///				2: responseString: String response from the request.
	static func request(url: URL,	method: String,	headers: [String: Any]?,	body: Data?,
						responseType: String,	timeout: TimeInterval,
						completion: @escaping (_ response: [Any?]) -> Void) {
		var urlRequest = URLRequest(url: url, timeoutInterval: timeout)
		urlRequest.httpMethod = method
		// Setting a Safari User-Agent, since we essentially are contacting from Safari
		// NB: This is for Safari v15.5 and might need to be periodically updated
		urlRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
		if let headers = headers {
			for data in headers {
				urlRequest.setValue("\(data.value)", forHTTPHeaderField: data.key)
			}
		}
		
		urlRequest.httpBody = body
		
		let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
			guard let httpResponse = response as? HTTPURLResponse else {
				completion(["error", ["message": error?.localizedDescription, "name": "SwiftError"]])
				return
			}
			let responseURL = httpResponse.url?.absoluteString ?? ""
			// Ensure the callback runs in the main queue where jscontext lives
			// or we risk corrupting the context and memory
			DispatchQueue.main.async {
				// Always return the raw data regardless of responseType
				completion([httpResponse.statusCode, data, httpResponse.allHeaderFields, responseURL])
			}
		}
		task.resume()
	}
	
	/// JavaScript-compatible HTTP request function that matches Zotero.HTTP.request in http_global.js
	/// - Parameters:
	///   - method: HTTP method (GET, POST, etc.)
	///   - urlString: URL string for the request
	///   - options: Dictionary of options matching the JavaScript API
	///   - callback: JavaScript callback function
	/// - Returns: Nothing, results passed to callback
	static func jsRequest(_ method: String, _ urlString: String, options: JSValue, callback: JSValue) {
		// Convert JSValue options to Swift dictionary
		let optionsDict = options.toDictionary() as? [String: Any] ?? [:]
		
		// Set default options
		let body = options.forProperty("body") as JSValue
		let headers = optionsDict["headers"] as? [String: Any] ?? [:]
		let timeout = (optionsDict["timeout"] as? Double ?? 15000) / 1000
		let responseType = optionsDict["responseType"] as? String ?? ""
		
		// Process URL
		guard let url = URL(string: urlString) ?? urlString.removingPercentEncoding.flatMap({ 
			$0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init) 
		}) else {
			callback.call(withArguments: [["error", ["message": "Invalid URL", "name": "InvalidURLError"]]])
			return
		}
		
		// Process body data
		let bodyData = HTTP.processBodyData(body)
		
		// Make the request
		request(url: url, method: method, headers: headers, body: bodyData, responseType: responseType, timeout: timeout) { response in
			if let errorResponse = response.first as? String, errorResponse == "error" {
				// Error occurred
				callback.call(withArguments: [response])
				return
			}
			
			guard let statusCode = response[0] as? Int,
					let responseData = response[1] as? Data,
					let headers = response[2] as? [AnyHashable: Any],
					let responseURL = response[3] as? String else {
				callback.call(withArguments: [["error", ["message": "Invalid response format", "name": "ResponseError"]]])
				return
			}
			
			// Process response based on responseType
			let responseObject: [String: Any]
			
			if responseType == "arraybuffer" {
				// For arraybuffer responses, create a proper JavaScript ArrayBuffer
				let jsContext = callback.context
				
				// Create an ArrayBuffer using the response data
				let nsData = responseData as NSData
				let dataLength = responseData.count
				
				// Retain the NSData for the lifetime of the JS ArrayBuffer; release in deallocator
				let retained = Unmanaged<NSData>.passRetained(nsData)
				let ctx = UnsafeMutableRawPointer(retained.toOpaque())
				let deallocator: JSTypedArrayBytesDeallocator = { (_, deallocatorContext) in
					if let deallocatorContext = deallocatorContext {
						Unmanaged<NSData>.fromOpaque(deallocatorContext).release()
					}
				}
				
				// Create a JavaScript ArrayBuffer without copying the bytes
				let arrayBuffer = JSObjectMakeArrayBufferWithBytesNoCopy(
					jsContext?.jsGlobalContextRef,
					UnsafeMutableRawPointer(mutating: nsData.bytes),
					dataLength,
					deallocator,
					ctx,
					nil
				)
				
				responseObject = [
					"status": statusCode,
					"responseText": "",  // Empty string for binary data
					"response": JSValue(jsValueRef: arrayBuffer, in: jsContext)!,
					"responseHeaders": headers,
					"responseURL": responseURL
				]
			} else {
				// Convert data to string for text responses
				let responseText = String(data: responseData, encoding: .utf8) ?? ""
				responseObject = [
					"status": statusCode,
					"responseText": responseText,
					"response": responseText,
					"responseHeaders": headers,
					"responseURL": responseURL
				]
			}
			
			callback.call(withArguments: [responseObject])
		}
	}
	
	/// Converts a JSValue body to Data based on its type
	/// - Parameter jsBody: The JSValue object that could be a string or ArrayBuffer
	/// - Returns: Converted Data or nil if conversion fails
	static func processBodyData(_ jsBody: JSValue?) -> Data? {
		guard let body = jsBody else { return nil }
		
		// Check if JSValue is JavaScript null or undefined
		if body.isNull || body.isUndefined {
			return nil
		}
		
		if body.isObject && body.hasProperty("byteLength") {
			// If it's an ArrayBuffer, directly access its bytes
			guard let jsContextRef = body.context.jsGlobalContextRef else { return nil }
			
			// Convert JSValue to JSObjectRef for use with ArrayBuffer APIs
			guard let jsObjectRef = JSValueToObject(jsContextRef, body.jsValueRef, nil) else {
				print("Failed to convert JSValue to JSObjectRef")
				return nil
			}
			
			guard let rawPointer = JSObjectGetArrayBufferBytesPtr(jsContextRef, jsObjectRef, nil) else {
				print("Failed to get ArrayBuffer bytes")
				return nil
			}
			
			// Convert to Data by copying bytes
			return Data(bytes: rawPointer, count: Int(truncating: body.forProperty("byteLength").toNumber()))
		} else if let bodyString = body.toString() {
			return bodyString.data(using: .utf8)
		}
		
		return nil
	}
}
