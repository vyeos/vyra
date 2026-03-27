//
//  CommandPaletteWindowController.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import SwiftUI

@MainActor
final class CommandPaletteWindowController: NSWindowController, NSWindowDelegate {
    init(viewModel: CommandPaletteViewModel) {
        let hostingController = NSHostingController(rootView: ContentView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)

        window.setContentSize(NSSize(width: 560, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.title = "Vyra"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func togglePalette() {
        guard let window else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            showPalette()
        }
    }

    func showPalette() {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
