//
//  AppDelegate.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppModel.shared.start()
        }
    }
}
