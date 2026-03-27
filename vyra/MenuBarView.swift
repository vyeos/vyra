//
//  MenuBarView.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel
    let openPalette: () -> Void
    let runWindowAction: (WindowAction) -> Void
    let revealMacroStorage: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vyra")
                    .font(.headline)
                Text("Phase 1 foundation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Command Palette", systemImage: "command") {
                openPalette()
            }
            .buttonStyle(.borderedProminent)

            Text("Shortcut: ⌘⇧Space")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Window Actions")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(WindowAction.allCases) { action in
                    Button(action.title, systemImage: action.systemImage) {
                        runWindowAction(action)
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.statusText)
                    .font(.footnote.weight(.medium))
                Text(viewModel.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let macroStoragePath = viewModel.macroStoragePath {
                Button("Reveal Macro Store", systemImage: "folder") {
                    revealMacroStorage()
                }
                .buttonStyle(.borderless)

                Text(macroStoragePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button("Quit", systemImage: "xmark.circle.fill") {
                NSApp.terminate(nil)
            }
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 340)
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}
