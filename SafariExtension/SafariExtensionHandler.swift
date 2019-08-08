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

    private func loadData(completed: @escaping (Int, String?) -> Void) {
        let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else { return }
            let responseData = data.flatMap({ try? JSONDecoder().decode(ApiResponseData.self, from: $0) })
            completed(httpResponse.statusCode, responseData?.title)
        }

        task.resume()
    }

    // MARK: - SFSafariExtensionHandler
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        switch messageName {
        case "loadData":
            self.loadData { code, title in
                page.dispatchMessageToScript(withName: "loadedData", userInfo: ["code": code,
                                                                                "title": title ?? ""])
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
