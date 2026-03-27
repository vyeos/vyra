//
//  AppModel.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Foundation

@MainActor
final class AppModel {
    static let shared = AppModel()

    let commandPaletteViewModel = CommandPaletteViewModel()

    private let hotKeyService = GlobalHotKeyService()
    private lazy var paletteWindowController = CommandPaletteWindowController(viewModel: commandPaletteViewModel)
    private var hasStarted = false

    private init() {
        hotKeyService.onHotKey = { [weak self] in
            self?.toggleCommandPalette()
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        hotKeyService.registerDefaultShortcut()

        Task {
            await commandPaletteViewModel.loadIfNeeded()
        }
    }

    func showCommandPalette() {
        start()
        paletteWindowController.showPalette()
    }

    func toggleCommandPalette() {
        start()
        paletteWindowController.togglePalette()
    }

    func runWindowAction(_ action: WindowAction) {
        start()
        commandPaletteViewModel.executeWindowAction(action)
    }

    func revealMacroStorage() {
        commandPaletteViewModel.revealMacroStorage()
    }
}
