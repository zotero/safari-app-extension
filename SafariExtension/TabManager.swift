//
//  TabManager.swift
//  SafariExtension
//
//  Created by Adomas Venckauskas on 2019-10-24.
//  Copyright © 2019 Corporation for Digital Scholarship. All rights reserved.
//

import Foundation
import SafariServices

// For some reason the references we get to SFSafariTab do not get properly
// retained when stored in a dict so we have to manually manage their memory.
// Since we are running in automatically managed memory mode
// calling .retain() directly on an object is not allowed
extension SFSafariTab {
	/// Same as retain(), which the compiler no longer lets us call:
	@discardableResult
	func retainMe() -> Self {
	  _ = Unmanaged.passRetained(self)
	  return self
	}

	/// Same as autorelease(), which the compiler no longer lets us call.
	///
	/// This function does an autorelease() rather than release() to give you more flexibility.
	@discardableResult
	func releaseMe() -> Self {
	  _ = Unmanaged.passUnretained(self).autorelease()
	  return self
	}
}

class TabManager {
	static var idsToTabs: [Int: SFSafariTab] = { 
			SFSafariApplication.getAllWindows() { windows in
				TabManager.cleanWindows(windows: windows) { }
			}
			return [ : ]
		}()
	
	class func getTabId(_ tab: SFSafariTab) -> Int {
		for (tabId, storedTab) in idsToTabs {
			if (storedTab.isEqual(tab)) {
				return tabId
			}
		}
		tab.retainMe()
		idsToTabs[tab.hashValue] = tab
		return tab.hashValue
	}
	
	class func getTab(id: Int, completion: @escaping (SFSafariTab?) -> Void) {
		SFSafariApplication.getAllWindows() { windows in
			self.cleanWindows(windows: windows) {
				completion(idsToTabs[id])
			}
		}
	}
	
	class func getActiveTabId(completion: @escaping (Int?) -> Void) {
		GlobalPage.getActiveWindow() { window in
			guard let window = window else {
				completion(nil)
				return
			}
			window.getActiveTab() { tab in
				guard let tab = tab else {
					completion(nil)
					return
				}
				completion(getTabId(tab))
			}
		}
	}
	
	private class func cleanWindows(windows: [SFSafariWindow], aliveTabs: [Int] = [], completion: @escaping () -> Void) {
		var aliveTabs = aliveTabs
		var windows = windows
		guard let window = windows.popLast() else {
			var deadTabs: [Int] = []
			for (tabId, _) in idsToTabs {
				if !aliveTabs.contains(tabId) {
					deadTabs.append(tabId)
				}
			}
			for tabId in deadTabs {
				let tab = idsToTabs[tabId]
				idsToTabs.removeValue(forKey: tabId)
				tab!.releaseMe()
			}
			completion()
			return
		}
		window.getAllTabs() { tabs in
			for (tabId, storedTab) in self.idsToTabs {
				for tab in tabs {
					if tab.isEqual(storedTab) {
						aliveTabs.append(tabId)
					}
				}
			}
			self.cleanWindows(windows: windows, aliveTabs: aliveTabs, completion: completion)
		}
	}
}
