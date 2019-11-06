//
//  GlobalPage.swift
//  SafariExtension
//
//  Created by Adomas Venckauskas on 06/09/2019.
//  Copyright © 2019 Corporation for Digital Scholarship. All rights reserved.
//

import Foundation
import JavaScriptCore
import SafariServices

let PREFS_KEY = "ConnectorPrefs"

class GlobalPage: NSObject {
	static var translators: [[String]] = []
	
	static var _sendMessageToGlobalPage: JavaScriptCore.JSValue? = {
		context?.evaluateScript("Zotero.Messaging.receiveSwiftMessage");
	}()
	
	static var context: JSContext? = {
			let context = JSContext()
			context?.exceptionHandler = onError
			
			// Add setTimeout
			JSInterval.provideToContext(context: context!)
			
			// Add console.log
			context?.setObject(consoleLog, forKeyedSubscript: "_consoleLog" as NSString)
			
			// Add the message handler
			context?.setObject(sendMessageToTab, forKeyedSubscript: "sendMessage" as NSString)
			
			// Load the global page JS
			let globalFiles = [
				"jscontext_shim.js",
				"node_modules.js",
				"zotero_config.js",
				"zotero.js",
				"i18n.js",
				"promise.js",
				"prefs.js",
				"api.js",
				"http.js",
				"http_global.js",
				"oauthsimple.js",
				"proxy.js",
				"connector.js",
				"cachedTypes.js",
				"zotero/date.js",
				"zotero/debug.js",
				"errors_webkit.js",
				"zotero/xregexp/xregexp.js",
				"zotero/xregexp/addons/build.js",
				"zotero/xregexp/addons/matchrecursive.js",
				"zotero/xregexp/addons/unicode/unicode-base.js",
				"zotero/xregexp/addons/unicode/unicode-categories.js",
				"zotero/xregexp/addons/unicode/unicode-zotero.js",
				"zotero/openurl.js",
				"repo.js",
				"zotero/translation/tlds.js",
				"zotero/translation/translator.js",
				"translators.js",
				"zotero/connectorTypeSchemaData.js",
				"zotero/utilities.js",
				"utilities.js",
				"zotero-google-docs-integration/api.js",
				"messages.js",
				"messaging.js",
				"messaging_global.js",
				"global.js"
			]
			
			for filepath in globalFiles {
				let ext = String(filepath.split(separator: ".").last!);
				let subpath = filepath.split(separator: "/").dropLast().joined(separator: "/");
				let filename = String(filepath.split(separator: "/").last!.split(separator: ".").first!);
				guard let fullpath = Bundle.main.path(forResource: filename, ofType: ext, inDirectory: subpath)
						?? Bundle.main.path(forResource: filename, ofType: ext, inDirectory: "safari/" + subpath) else {
					print("Unable to read resource file " + subpath + filename)
					return nil
				}
				
				do {
					let script = try String(contentsOfFile: fullpath, encoding: String.Encoding.utf8)
					_ = context?.evaluateScript(script, withSourceURL: URL(string: filepath))
				} catch (let error) {
					print("Error while processing script file: \(error)")
					return nil
				}
			}
			
			return context
		}()
	
	static func sendMessageToGlobalPage(name: String, args: Any = [], id: Int? = nil, page: SFSafariPage? = nil) {
		let id = id ?? UUID().hashValue
		guard let page = page else {
			getActiveWindow { window in
				if (window != nil) {
					window?.getActiveTab { tab in
						guard let tab = tab else {
							GlobalPage._sendMessageToGlobalPage?.call(withArguments: [name, id, args, -1])
							return;
						}
//						print("Sending message to global \(id) \(args as? String)")
						GlobalPage._sendMessageToGlobalPage?.call(withArguments: [name, id, args, TabManager.getTabId(tab)])
					}
				} else {
					GlobalPage._sendMessageToGlobalPage?.call(withArguments: [name, id, args, -1])
				}
			}
			return
		}
		page.getContainingTab() { tab in
			// print("Sending message to global \(id) \(args as? String)")
			GlobalPage._sendMessageToGlobalPage?.call(withArguments: [name, id, args, TabManager.getTabId(tab)])
		}
	}
	
	// Called from the global page to communicate with safari injected scripts
	private static let sendMessageToTab: @convention(block) (Any, Any, Any?, Int) -> (Bool) = { (name: Any, id: Any, args: Any?, tabId: Int?) in
		guard let name = name as? String,
			let id = id as? Int else {
				print("Failure: Incorrect arguments in sendMessageToTab")
				return false;
		}
		// Some requests are handled in swift
//		print("Received \(name) \(id)")
		switch name {
		case "HTTP.request":
			guard let args = args as? [String: Any] else {
				print("Failure: Incorrect arguments in \(name)")
				return false;
			}
			HTTP.request(with: args) { response in
				sendMessageToGlobalPage(name: "response", args: response, id: id)
			}
			return true
		case "Swift.openWindow":
			return openWindow(with: args)
		case "Swift.openTab":
			return openTab(with: args)
		case "Swift.closeTab":
			return closeTab(with: args)
		case "Swift.activate":
			// This might not do anything useful...
			getActiveWindow { window in
				window?.getActiveTab { tab in
					tab?.activate()
				}
			}
			return true
		case "Swift.getVersion":
			sendMessageToGlobalPage(name: "response", args: Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "5.1", id: id)
			return true
		case "Swift.getBaseURI":
			SFSafariExtension.getBaseURI() { uri in
				sendMessageToGlobalPage(name: "response", args: uri?.absoluteString as Any, id: id)
			}
			return true
		case "Swift.getLocale":
			return getLocale(id: id)
		case "Swift.getPrefs":
			return getPrefs(id: id)
		case "Swift.setPrefs":
			return setPrefs(args, id: id)
		case "Swift.updateButton":
			return updateButton(args, tabId: tabId)
		case "Swift.globalAvailable":
			return sendGlobalAvailableToAllTabs()
		default:
			break
		}
		// Sending to the tab provided by the tabId from the global page
		if (tabId != nil) {
			TabManager.getTab(id: tabId!) { tab in
				guard let tab = tab else {
					print("Attempted to send a message \(name) to a dead tab \(String(describing: tabId))")
					return
				}
				tab.getActivePage { activePage in
					activePage?.dispatchMessageToScript(withName: name, userInfo: ["args": [args, id]])
				}
				return
			}
			return true
		}
		
		// Sending to the active tab
		getActiveWindow() { window in
			window?.getActiveTab { activeTab in
				activeTab?.getActivePage { activePage in
					activePage?.dispatchMessageToScript(withName: name, userInfo: ["args": [args, id]])
				}
			}
		}
		return true;
	}
	
	// Apparently if there is no window the completion handler is never called (so why is the argument
	// of the completion handler an Optional?!), so we have to set up a timeout for this manually since
	// our program flow depends on the handler being called
	class func getActiveWindow(completionHandler: @escaping (SFSafariWindow?) -> Void) {
		var isComplete = false
		// If completion handler not called in 2 seconds it probably won't happen.
		Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (timer) in
			if isComplete {
				return
			}
			isComplete = true
			completionHandler(nil)
		}
		SFSafariApplication.getActiveWindow { window in
			if isComplete {
				return
			}
			isComplete = true
			completionHandler(window)
		}
	}
	
	
	private static let consoleLog: @convention(block) (String) -> Void = { message in
		print(message)
	}
	
	private class func onError(ctx: JSContext!, error: JSValue!) {
		print("Global Error: \(error.toString() ?? "undefined")")
	}
	
	// Must handle this here since there are no close events
	// so we have to keep polling open tabs for the onClose handler
	private class func openWindow(with args: Any?) -> Bool {
		var allowedCharacterSet = CharacterSet()
		allowedCharacterSet.insert(charactersIn: "/:")
		guard let args = args as? [Any],
			let urlStr = args[0] as? String,
			let url = URLComponents(string: urlStr.replacingOccurrences(of: " ", with: "%20"))?.url else {
				print("Failure: Incorrect arguments in openWindow")
				return false;
		}
		SFSafariApplication.openWindow(with: url) { window in
			if let onCloseFn = args[1] as? JSValue {
				Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
					SFSafariApplication.getAllWindows { windows in
						var windowStillOpen = false;
						for openWindow in windows {
							if openWindow.isEqual(window) {
								windowStillOpen = true;
							}
						}
						if !windowStillOpen {
							onCloseFn.call(withArguments: [])
							timer.invalidate();
						}
					}
				}
			}
		}
		return true
	}
	
	private class func openTab(with args: Any?) -> Bool {
		var allowedCharacterSet = CharacterSet()
		allowedCharacterSet.insert(charactersIn: "/:")
		guard let args = args as? [Any],
			let urlStr = args[0] as? String,
			let url = URLComponents(string: urlStr.replacingOccurrences(of: " ", with: "%20"))?.url else {
				print("Failure: Incorrect arguments in openTab")
				return false;
		}
		getActiveWindow { window in
			window?.openTab(with: url, makeActiveIfPossible: true) {tab in}
		}
		return true
	}
	
	private class func closeTab(with args: Any?) -> Bool {
		guard let args = args as? [Any],
			let tabId = args[0] as? Int else {
			print("Failure: Incorrect arguments in closeTab")
			return false
		}
		TabManager.getTab(id: tabId) { tab in
			tab?.close()
		}
		return true
	}
	
	private class func getLocale(id messageId: Int) -> Bool {
		let subpath = "safari/_locales/"
		guard let fullpath = Bundle.main.path(forResource: "messages", ofType: "json", inDirectory: subpath + Locale.current.languageCode!)
			?? Bundle.main.path(forResource: "messages", ofType: "json", inDirectory: subpath + "en") else {
				print("Unable to read locale file")
				return false
		}
		
		do {
			let localeJSON = try String(contentsOfFile: fullpath, encoding: .utf8)
			sendMessageToGlobalPage(name: "response", args: localeJSON, id: messageId)
		}
		catch (let error) {
			print("Error while processing script file: \(error)")
			return false
		}
		return true
	}
	
	private class func getPrefs(id messageId: Int) -> Bool {
		let prefs = UserDefaults.standard.string(forKey: PREFS_KEY) ?? "{}"
		sendMessageToGlobalPage(name: "response", args: prefs, id: messageId)
		return true
	}
	
	private class func setPrefs(_ args: Any?, id messageId: Int) -> Bool {
		guard let prefs = args as? String else {
			print("Failure: Incorrect arguments in setPrefs")
			return false
		}
		UserDefaults.standard.set(prefs, forKey: PREFS_KEY)
		return true
	}
	
	private class func updateButton(_ args: Any?, tabId: Int?) -> Bool {

		guard let args = args as? [Any],
			let imagePath = args[0] as? String,
			let tooltip = args[1] as? String,
			let translators = args[2] as? [[String]]
		else {
				print(	"Failure: Incorrect arguments in updateButton")
				return false
		}
		self.translators = translators
	    let subpath = "safari/" + imagePath.split(separator: "/").dropLast().joined(separator: "/");
	    let filename = String(imagePath.split(separator: "/").last!.split(separator: ".").first!);
	    guard let fullpath = Bundle.main.path(forResource: filename, ofType: "png", inDirectory: subpath) else {
	        print("Unable to read toolbar image file \(filename)")
			return false
	    }
		TabManager.getActiveTabId() { activeTabId in
			guard tabId != nil && activeTabId != nil && tabId == activeTabId else {
				return
			}
			SFSafariApplication.getActiveWindow() { window in
				window?.getToolbarItem() { button in
					button?.setLabel(tooltip)
					button?.setImage(NSImage(contentsOfFile: fullpath))
				}
			}
		}
	    
		return true
	}
	
	private class func sendGlobalAvailableToAllTabs() -> Bool {
		SFSafariApplication.getAllWindows() { windows in
			for window in windows {
				window.getAllTabs() { tabs in
					for tab in tabs {
						tab.getActivePage() { page in
							page?.dispatchMessageToScript(withName: "globalAvailable", userInfo: ["args": []])
						}
					}
				}
			}
		}
		return true
	}
}
