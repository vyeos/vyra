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
    let revealMacroStorage: () -> Void
    let openSettings: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                openPalette()
                dismiss()
            } label: {
                HStack {
                    Text("Open Vyra")
                    Spacer()
                    Text("⌘⇧Space")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GhostButtonStyle())

            Divider()
                .padding(.vertical, 2)

            recordingSection

            Divider()
                .padding(.vertical, 2)

            Button {
                revealMacroStorage()
                dismiss()
            } label: {
                HStack {
                    Text("Reveal Macro Store")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(viewModel.macroStoragePath == nil)

            if !viewModel.recentMacros.isEmpty {
                Text("Recent Macros")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                ForEach(viewModel.recentMacros) { macro in
                    Button {
                        viewModel.macroReplayer.replay(macro: macro)
                        dismiss()
                    } label: {
                        HStack {
                            Text(macro.name)
                            Spacer()
                            if let shortcut = macro.shortcut {
                                Text(shortcutDisplayString(shortcut))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }

            Divider()
                .padding(.vertical, 2)

            Button {
                openSettings()
                dismiss()
            } label: {
                HStack {
                    Text("Settings")
                    Spacer()
                    Text("Key Behavior")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GhostButtonStyle())

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Text("Quit")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(8)
        .frame(width: 300)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var recordingSection: some View {
        if viewModel.macroRecorder.isRecording {
            Button {
                if let macro = viewModel.stopMacroRecording() {
                    viewModel.saveMacro(macro)
                }
                dismiss()
            } label: {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("Stop Recording")
                    Spacer()
                    Text("\(viewModel.macroRecorder.stepCount) steps")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GhostButtonStyle())

            Button {
                viewModel.macroRecorder.cancelRecording()
                dismiss()
            } label: {
                HStack {
                    Text("Cancel Recording")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GhostButtonStyle())
        } else {
            Button {
                viewModel.startMacroRecording()
                openPalette()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                    Text("Start Macro Recording")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GhostButtonStyle())
        }
    }


    private func shortcutDisplayString(_ shortcut: MacroShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 {
            parts.append("⌃")
        }
        if shortcut.modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 {
            parts.append("⌥")
        }
        if shortcut.modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            parts.append("⇧")
        }
        if shortcut.modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 {
            parts.append("⌘")
        }
        let keyName = keyCodeToString(shortcut.keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        default: return "?"
        }
    }
}

struct GhostButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isHovered ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .onHover { hovering in
                isHovered = hovering
            }
            .contentShape(Rectangle())
    }
}
