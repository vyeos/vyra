//
//  AppModel.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Carbon
import Foundation

@MainActor
final class AppModel {
    static let shared = AppModel()

    let commandPaletteViewModel = CommandPaletteViewModel()

    private let hotKeyService = GlobalHotKeyService()
    private lazy var paletteWindowController = CommandPaletteWindowController(viewModel: commandPaletteViewModel)
    private lazy var settingsWindowController = SettingsWindowController(viewModel: commandPaletteViewModel)
    private lazy var onboardingWindowController = OnboardingWindowController(viewModel: commandPaletteViewModel)
    private var hasStarted = false

    private init() {
        hotKeyService.onHotKey = { [weak self] in
            self?.toggleCommandPalette()
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // Load settings before checking onboarding.
        try? commandPaletteViewModel.settingsStore.prepareStorage()

        if !commandPaletteViewModel.settingsStore.hasCompletedOnboarding {
            onboardingWindowController.showOnboarding()
        }

        registerPaletteHotkeyFromSettings()

        Task {
            await commandPaletteViewModel.loadIfNeeded()
        }
    }

    func registerPaletteHotkeyFromSettings() {
        let assignments = commandPaletteViewModel.settingsStore.hotkeyAssignments
        let shortcut = assignments["vyra:openPalette"]

        if let shortcut {
            let carbonMods = Self.carbonModifiers(from: shortcut.modifiers)
            hotKeyService.register(keyCode: shortcut.keyCode, modifiers: carbonMods)
        } else {
            hotKeyService.registerDefaultShortcut()
        }
    }

    private static func carbonModifiers(from encoded: UInt32) -> UInt32 {
        var mods: UInt32 = 0
        if encoded & (1 << 0) != 0 { mods |= UInt32(cmdKey) }
        if encoded & (1 << 1) != 0 { mods |= UInt32(shiftKey) }
        if encoded & (1 << 2) != 0 { mods |= UInt32(optionKey) }
        if encoded & (1 << 3) != 0 { mods |= UInt32(controlKey) }
        return mods
    }

    func showCommandPalette() {
        start()
        paletteWindowController.showPalette()
    }

    func toggleCommandPalette() {
        start()
        paletteWindowController.togglePalette()
        // Notify observers (e.g. onboarding page 4) that the palette was opened.
        NotificationCenter.default.post(name: .vyraCommandPaletteDidOpen, object: nil)
    }

    func runWindowAction(_ action: WindowAction) {
        start()
        commandPaletteViewModel.executeWindowAction(action)
    }

    func startMacroRecording() {
        start()
        commandPaletteViewModel.startMacroRecording()
        showCommandPalette()
    }

    func stopMacroRecording() {
        if let macro = commandPaletteViewModel.stopMacroRecording() {
            commandPaletteViewModel.saveMacro(macro)
        }
    }

    func revealMacroStorage() {
        commandPaletteViewModel.revealMacroStorage()
    }

    func applyCurrentTheme() {
        Task {
            await commandPaletteViewModel.themeManager.applyTheme()
        }
    }

    func showSettings() {
        start()
        settingsWindowController.showSettings()
    }
}
