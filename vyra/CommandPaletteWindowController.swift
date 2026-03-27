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
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var escapeKeyMonitor: Any?

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
        stopEventMonitors()
    }

    private func startEventMonitor() {
        stopEventMonitors()

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePalette()
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = self.window else { return event }
            if event.window != window {
                self.hidePalette()
            }
            return event
        }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.hidePalette()
                return nil
            }
            return event
        }
    }

    private func stopEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePalette()
        return false
    }

    func windowDidResignKey(_ notification: Notification) {
        hidePalette()
    }

    nonisolated private func removeEventMonitor(_ monitor: Any?) {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    deinit {
        removeEventMonitor(globalEventMonitor)
        removeEventMonitor(localEventMonitor)
        removeEventMonitor(escapeKeyMonitor)
    }
}
