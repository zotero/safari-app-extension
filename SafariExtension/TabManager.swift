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
    private static let accessQueue = DispatchQueue.global(qos: .utility)

    private static var _idsToTabs: [Int: SFSafariTab] = {
        SFSafariApplication.getAllWindows() { windows in
            TabManager.cleanWindows(windows: windows) { }
        }
        return [ : ]
    }()

	static var idsToTabs: [Int: SFSafariTab] {
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
			var newIdsToTabs: [Int : SFSafariTab] = [ : ]
			for id in aliveTabs {
				guard let tab = idsToTabs[id] else {
					continue
				}
				newIdsToTabs.updateValue(tab, forKey: id)
			}
			idsToTabs = newIdsToTabs
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
