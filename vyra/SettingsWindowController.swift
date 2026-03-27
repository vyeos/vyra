//
//  SettingsWindowController.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(viewModel: CommandPaletteViewModel) {
        let contentSize = NSSize(width: 520, height: 440)
        let hostingController = NSHostingController(rootView: SettingsView(viewModel: viewModel))

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(contentSize)
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        weak let weakWindow = window
        hostingController.rootView = SettingsView(
            viewModel: viewModel,
            onDone: { weakWindow?.performClose(nil) }
        )

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettings() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        // Center after the window is visible + SwiftUI applies its final sizing.
        DispatchQueue.main.async { [weak window] in
            window?.contentView?.layoutSubtreeIfNeeded()
            window?.center()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
