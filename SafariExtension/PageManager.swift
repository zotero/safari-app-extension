//
//  PageManager.swift
//  SafariExtension
//
//  Created by Adomas Venckauskas on 2019-10-24.
//  Copyright © 2019 Corporation for Digital Scholarship. All rights reserved.
//

import Foundation
import SafariServices

class PageManager {
	static var idsToPages: [Int: SFSafariPage] = {
			SFSafariApplication.getAllWindows() { windows in
				PageManager.cleanWindows(windows: windows) { }
			}
			return [ : ]
		}()
	
	class func getPageId(_ page: SFSafariPage) -> Int {
		for (tabId, storedPage) in idsToPages {
			if (storedPage.isEqual(page)) {
				return tabId
			}
		}
		idsToPages[page.hashValue] = page
		return page.hashValue
	}
	
	class func getPage(id: Int, completion: @escaping (SFSafariPage?) -> Void) {
		SFSafariApplication.getAllWindows() { windows in
			self.cleanWindows(windows: windows) {
				completion(idsToPages[id])
			}
		}
	}
	
	class func getActivePageId(completion: @escaping (Int?) -> Void) {
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
				tab.getActivePage() { page in
					guard let page = page else {
						completion(nil)
						return
					}
					completion(getPageId(page))
				}
			}
		}
	}
	
	private class func cleanWindows(windows: [SFSafariWindow], alivePages: [Int] = [], completion: @escaping () -> Void) {
		var windows = windows
		var alivePages = alivePages
		guard let window = windows.popLast() else {
			var newIdsToPages: [Int : SFSafariPage] = [ : ]
			for id in alivePages {
				guard let page = idsToPages[id] else {
					continue
				}
				newIdsToPages.updateValue(page, forKey: id)
			}
			idsToPages = newIdsToPages
			completion()
			return
		}
		window.getAllTabs() { tabs in
			self.cleanTabs(tabs: tabs, alivePages: alivePages) { pages in
				alivePages = pages
				self.cleanWindows(windows: windows, alivePages: alivePages, completion: completion)
			}
		}
	}
	
	private class func cleanTabs(tabs: [SFSafariTab], alivePages: [Int], completion: @escaping ([Int]) -> Void) {
		var alivePages = alivePages
		var tabs = tabs
		guard let tab = tabs.popLast() else {
			completion(alivePages)
			return
		}
		tab.getActivePage() { page in
			guard let page = page else {
				cleanTabs(tabs: tabs, alivePages: alivePages, completion: completion)
				return
			}
			for (pageId, storedPage) in idsToPages {
				if (storedPage.isEqual(page)) {
					alivePages.append(pageId)
					break
				}
			}
			cleanTabs(tabs: tabs, alivePages: alivePages, completion: completion)
		}
	}
}
