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

    var body: some Scene {
        MenuBarExtra(
            "Vyra",
            systemImage: "command.square"
        ) {
            MenuBarView(
                viewModel: AppModel.shared.commandPaletteViewModel,
                openPalette: { AppModel.shared.showCommandPalette() },
                revealMacroStorage: { AppModel.shared.revealMacroStorage() }
            )
        }
        .menuBarExtraStyle(.window)
    }
}
