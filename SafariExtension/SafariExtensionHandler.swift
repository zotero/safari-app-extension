//
//  SafariExtensionHandler.swift
//  SafariExtension
//
//  Copyright © 2019 Corporation for Digital Scholarship
//

import SafariServices

struct ApiResponseData: Decodable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}

class SafariExtensionHandler: SFSafariExtensionHandler {

    // MARK: - Actions

    /// Performs a HTTP request from provided data.
    /// - parameter data: Data for HTTP request. Data has to contain a valid url string and http method.
    ///                   Data can contain additional options for the request, such as headers, body and timeout.
    /// - parameter completion: Completion block of request.
    /// - parameter statusCode: Response status code. Can be -1 if URL was not specified correctly
    ///                         or -2 if Method was not specified.
    /// - parameter url: URL of HTTP request.
    /// - parameter response: String response from the request.
    private func performHttpRequest(with data: [String: Any],
                                    completion: @escaping (_ statusCode: Int, _ url: String, _ response: String?) -> Void) {
        guard let urlString = data["url"] as? String,
              let url = URL(string: urlString) else {
            completion(-1, "missing/incorrect url", nil)
            return
        }

        guard let method = data["method"] as? String else {
            completion(-2, urlString, nil)
            return
        }

        let options = data["options"] as? [String: Any] ?? [:]
        let headers = options["headers"] as? [String: Any]
        let body = (options["body"] as? String).flatMap({ $0.data(using: .utf8) })
        let timeout = (options["timeout"] as? Double) ?? 60

        self.performHttpRequest(url: url, method: method, headers: headers,
                                body: body, timeout: timeout, completion: completion)
    }

    /// Perform a HTTP request.
    /// - parameter url: URL for the request.
    /// - parameter method: HTTP method of the request.
    /// - parameter headers: Optional HTTP headers for the request.
    /// - parameter body: Optional body data for request.
    /// - parameter timeout: Timeout interval of the request.
    /// - parameter completion: Completion block of request.
    /// - parameter statusCode: Response status code. Can be -1 if URL was not specified correctly
    ///                         or -2 if Method was not specified.
    /// - parameter url: URL of HTTP request.
    /// - parameter response: String response from the request.
    private func performHttpRequest(url: URL, method: String, headers: [String: Any]?,
                                    body: Data?, timeout: TimeInterval,
                                    completion: @escaping (_ statusCode: Int, _ url: String, _ response: String?) -> Void) {
        var urlRequest = URLRequest(url: url, timeoutInterval: timeout)
        urlRequest.httpMethod = method
        if let headers = headers {
            for data in headers {
                urlRequest.setValue("\(data.value)", forHTTPHeaderField: data.key)
            }
        }
        urlRequest.httpBody = body

        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else { return }
            let strResponse = data.flatMap({ String(data: $0, encoding: .utf8) })
            completion(httpResponse.statusCode, url.absoluteString, strResponse)
        }
        task.resume()
    }

    // MARK: - SFSafariExtensionHandler
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        switch messageName {
        case "performHttpRequest":
            if let data = userInfo {
                self.performHttpRequest(with: data) { statusCode, url, strResponse in
                    page.dispatchMessageToScript(withName: "httpResponse", userInfo: ["url": url,
                                                                                      "statusCode": statusCode,
                                                                                      "response": (strResponse ?? "")])
                }
            }
        default: break
        }
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
        window.getActiveTab { (activeTab) in
            activeTab?.getActivePage { (activePage) in
                activePage?.dispatchMessageToScript(withName: "translate", userInfo: nil)
            }
        }
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
