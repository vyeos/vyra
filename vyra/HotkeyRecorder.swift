//
//  HotkeyRecorder.swift
//  vyra
//
//  Reusable hotkey recorder components extracted from SettingsView.
//

import AppKit
import SwiftUI

/// A sheet that presents a hotkey recording prompt.
struct HotkeyRecorderSheet: View {
    let title: String
    let onCancel: () -> Void
    let onRecorded: (KeyboardShortcut) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text("Press modifiers + one key. Esc to cancel.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HotkeyRecorderView { shortcut in
                onRecorded(shortcut)
            } onCancel: {
                onCancel()
            }
            .frame(height: 44)

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
    }
}

/// An NSViewRepresentable that captures keyboard events for shortcut recording.
struct HotkeyRecorderView: NSViewRepresentable {
    let onRecorded: (KeyboardShortcut) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onRecorded = onRecorded
        view.onCancel = onCancel
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {}
}

final class RecorderNSView: NSView {
    var onRecorded: ((KeyboardShortcut) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onCancel?()
            return
        }

        // Ignore if it's only a modifier key press.
        if [54, 55, 56, 57, 58, 59, 60, 61, 62].contains(Int(event.keyCode)) {
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

        var encodedMods: UInt32 = 0
        if modifiers.contains(.command) { encodedMods |= 1 << 0 }
        if modifiers.contains(.shift) { encodedMods |= 1 << 1 }
        if modifiers.contains(.option) { encodedMods |= 1 << 2 }
        if modifiers.contains(.control) { encodedMods |= 1 << 3 }

        onRecorded?(KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: encodedMods))
    }
}

/// Helper to convert a keyCode to a human-readable string.
func keyCodeToDisplayString(_ keyCode: UInt32) -> String {
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
    case 49: return "Space"
    case 50: return "`"
    default: return "?"
    }
}

/// Format a KeyboardShortcut for display, with optional hyper key symbol.
func shortcutDisplayString(_ shortcut: KeyboardShortcut?, preferHyperSymbol: Bool = false, hyperIncludesShift: Bool = false) -> String {
    guard let shortcut else { return "None" }

    let mods = shortcut.modifiers
    let key = keyCodeToDisplayString(shortcut.keyCode)

    let cmd: UInt32 = 1 << 0
    let shift: UInt32 = 1 << 1
    let opt: UInt32 = 1 << 2
    let ctrl: UInt32 = 1 << 3

    let isCmd = (mods & cmd) != 0
    let isShift = (mods & shift) != 0
    let isOpt = (mods & opt) != 0
    let isCtrl = (mods & ctrl) != 0

    let wantsHyper = preferHyperSymbol && isCmd && isOpt && isCtrl && (!hyperIncludesShift || isShift)

    var parts: [String] = []
    if wantsHyper {
        parts.append("✦")
        if !hyperIncludesShift, isShift {
            parts.append("⇧")
        }
    } else {
        if isCtrl { parts.append("⌃") }
        if isOpt { parts.append("⌥") }
        if isShift { parts.append("⇧") }
        if isCmd { parts.append("⌘") }
    }

    parts.append(key)
    return parts.joined()
}
