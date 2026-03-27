//
//  vyraApp.swift
//  vyra
//
//  Created by Rudra Patel on 25/03/26.
//

import SwiftUI
// import SwiftData

@main
struct vyraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: CommandPaletteViewModel

    init() {
        _viewModel = StateObject(wrappedValue: AppModel.shared.commandPaletteViewModel)
    }

    var body: some Scene {
        MenuBarExtra(
            "Vyra",
            systemImage: "command.square",
            isInserted: Binding(
                get: { viewModel.settingsStore.showInMenuBar },
                set: { viewModel.settingsStore.showInMenuBar = $0 }
            )
        ) {
            MenuBarView(
                viewModel: viewModel,
                openPalette: { AppModel.shared.showCommandPalette() },
                revealMacroStorage: { AppModel.shared.revealMacroStorage() },
                openSettings: { AppModel.shared.showSettings() }
            )
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    AppModel.shared.showSettings()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}
