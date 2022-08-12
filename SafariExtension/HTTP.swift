//
//  HTTP.swift
//  SafariExtension
//
//  Created by Adomas Venckauskas on 27/08/2019.
//  Copyright © 2019 Corporation for Digital Scholarship. All rights reserved.
//

import Foundation

enum HTTP {
	/// Performs a HTTP request from provided data.
	/// - parameter data: Data for HTTP request. Data has to contain a valid url string and http method.
	///                   Data can contain additional options for the request, such as headers, body and timeout.
	/// - parameter completion: Completion block of request.
	/// - parameter response:
	/// 				0: statusCode: Response status code. Can be -1 if URL was not specified correctly
	///                         or -2 if Method was not specified.
	///				1: url (error message)
	///				2: responseString: String response from the request.
	static func request(with data: [String: Any],
						completion: @escaping (_ response: [Any?]) -> Void) {
		guard let urlString = data["url"] as? String,
			  let url = URL(string: urlString) ?? urlString.removingPercentEncoding.flatMap({ $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init) }) else {
				completion([-1, "missing/incorrect url", nil])
				return
		}
		
		guard let method = data["method"] as? String else {
			completion([-2, urlString, nil])
			return
		}
		
		let options = data["options"] as? [String: Any] ?? [:]
		let headers = options["headers"] as? [String: Any]
		let responseType = options["responseType"] as? String ?? ""
		let body = (options["body"] as? String).flatMap({ $0.data(using: .utf8) })
		// This is passed in miliseconds instead of seconds from JS
		let timeout = ((options["timeout"] as? Double) ?? 15000) / 1000
		
		self.request(url: url, method: method, headers: headers,
					 body: body, responseType: responseType, timeout: timeout, completion: completion)
	}
	
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
			if (responseType == "arraybuffer") {
				var bytesResponse: [UInt8]? = nil
				if let unwrappedData = data {
					bytesResponse = [UInt8](unwrappedData)
				}
				
				completion([httpResponse.statusCode, bytesResponse, httpResponse.allHeaderFields, responseURL])
			} else {
				let strResponse = data.flatMap({ String(data: $0, encoding: .utf8) })
				completion([httpResponse.statusCode, strResponse, httpResponse.allHeaderFields, responseURL])
			}
		}
		task.resume()
	}
}
