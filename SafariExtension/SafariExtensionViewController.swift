//
//  SafariExtensionViewController.swift
//  SafariExtension
//
//  Created by Michal Rentka on 30/05/2019.
//  Copyright © 2019 Michal Rentka. All rights reserved.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:320, height:240)
        return shared
    }()

}
