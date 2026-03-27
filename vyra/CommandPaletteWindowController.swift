//
//  CommandPaletteWindowController.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import SwiftUI

final class PaletteWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class CommandPaletteWindowController: NSWindowController, NSWindowDelegate {
    private var eventMonitor: Any?

    init(viewModel: CommandPaletteViewModel) {
        let hostingController = NSHostingController(rootView: ContentView(viewModel: viewModel, onClose: {
            Task { @MainActor in
                NSApp.keyWindow?.orderOut(nil)
            }
        }))
        let window = PaletteWindow(contentViewController: hostingController)

        window.setContentSize(NSSize(width: 560, height: 420))
        window.styleMask = [.fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]
        window.center()
        window.backgroundColor = .clear
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true

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
            hidePalette()
        } else {
            showPalette()
        }
    }

    func showPalette() {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        startEventMonitor()
    }

    func hidePalette() {
        guard let window else { return }
        window.orderOut(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePalette()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePalette()
        return false
    }

    nonisolated private func removeEventMonitor(_ monitor: Any?) {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    deinit {
        removeEventMonitor(eventMonitor)
    }
}
