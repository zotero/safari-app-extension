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
	override init() {
		super.init()
		_ = GlobalPage._sendMessageToGlobalPage
	}
	
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
		guard let message = userInfo?["message"] as? String,
			let messageID = userInfo?["messageId"] as? Int,
			let args = userInfo?["args"] as Any?
		else {
			return
		}
        switch message {
		case "Connector_Browser.onPageLoad":
			guard var args = args as? [Any] else {
				return
			}
			page.getPropertiesWithCompletionHandler() { (pageProperties: SFSafariPageProperties?) in
				args.insert(pageProperties?.title ?? "N/A", at: 0)
				GlobalPage.sendMessageToGlobalPage(name: message, args: args, id: messageID, page: page)
				
			}
			break
		default:
			// print("Forwarding message to global page: \(message)")
			GlobalPage.sendMessageToGlobalPage(name: message, args: args, id: messageID, page: page)
        }
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
		window.getActiveTab { (activeTab: SFSafariTab?) in
			activeTab?.getActivePage { (activePage: SFSafariPage?) in
				activePage?.dispatchMessageToScript(withName: "buttonClick", userInfo: ["args": []])
			}
        }
    }
    
	// We have 10 placeholder context items in Info.plist that we will display depending on
	// how many translators the page has. This is also where we set their text.
	override func validateContextMenuItem(withCommand command: String, in page: SFSafariPage, userInfo: [String : Any]? = nil, validationHandler: @escaping (Bool, String?) -> Void) {
		let index = command.last!.wholeNumberValue!
		if (index < GlobalPage.translators.count && index < 9) {
			validationHandler(false, GlobalPage.translators[index][1])
		} else if (index == GlobalPage.translators.count || GlobalPage.translators.count > 9) {
			// The final item is Zotero Preferences. If there are more than 9 translators we ignore the subsequent ones
			// to ensure users can always get to Zotero Preferences
			validationHandler(false, "Zotero Preferences")
		} else {
			validationHandler(true, nil)
		}
    }
	
	override func contextMenuItemSelected(withCommand command: String, in page: SFSafariPage, userInfo: [String : Any]? = nil) {
        let index = command.last!.wholeNumberValue!
		if (index == GlobalPage.translators.count || GlobalPage.translators.count > 9 && index == 9) {
			GlobalPage.sendMessageToGlobalPage(name: "onContextMenuItem", args: ["prefs"])
		} else {
			GlobalPage.sendMessageToGlobalPage(name: "onContextMenuItem", args: GlobalPage.translators[index][0])
		}
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
