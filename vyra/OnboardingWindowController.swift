//
//  OnboardingWindowController.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    init(viewModel: CommandPaletteViewModel) {
        let hostingController = NSHostingController(
            rootView: OnboardingView(viewModel: viewModel)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Vyra"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 460))
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showOnboarding() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
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
