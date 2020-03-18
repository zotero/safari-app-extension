//
//  TabManager.swift
//  SafariExtension
//
//  Created by Adomas Venckauskas on 2019-10-24.
//  Copyright © 2019 Corporation for Digital Scholarship. All rights reserved.
//

import Foundation
import SafariServices

class TabManager {
	private static let accessQueue = DispatchQueue(label: "org.zotero.TabManagerAccessQueue", qos: .utility)

	private static var _idsToTabs: [Int: SFSafariTab] = [:]

	class var idsToTabs: [Int: SFSafariTab] {
		get {
			var ids: [Int: SFSafariTab] = [:]
			accessQueue.sync {
				ids = _idsToTabs
			}
			return ids
		}

		set {
			accessQueue.async(flags: .barrier) {
				_idsToTabs = newValue
			}
		}
	}
	
	class func getTabId(_ tab: SFSafariTab) -> Int {
		for (tabId, storedTab) in idsToTabs {
			if (storedTab.isEqual(tab)) {
				return tabId
			}
		}
		idsToTabs[tab.hashValue] = tab
		return tab.hashValue
	}
	
	class func getTab(id: Int, completion: @escaping (SFSafariTab?) -> Void) {
		SFSafariApplication.getAllWindows() { windows in
			let tabs = idsToTabs
			reloadTabs(existingTabs: tabs, windows: windows) { newTabs in
				idsToTabs = newTabs
				completion(newTabs[id])
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

	private class func reloadTabs(existingTabs: [Int: SFSafariTab], windows: [SFSafariWindow],
								  activeTabIds: [Int] = [], completion: @escaping ([Int: SFSafariTab]) -> Void) {
		// Go through all tabs for last window
		if let window = windows.last {
			var ids = activeTabIds
			window.getAllTabs { tabs in
				for (id, tab) in existingTabs {
					if tabs.contains(where: { $0.isEqual(tab) }) {
						ids.append(id)
					}
				}
				// Recursively go through all windows
				self.reloadTabs(existingTabs: existingTabs, windows: windows.dropLast(), activeTabIds: ids, completion: completion)
			}
			return
		}

		// All windows and tabs checked, return results
		var tabs: [Int: SFSafariTab] = [:]
		for id in activeTabIds {
			guard let tab = existingTabs[id] else { continue }
			tabs[id] = tab
		}
		completion(tabs)
	}
}
