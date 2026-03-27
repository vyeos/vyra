//
//  SettingsView.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private enum Tab: Hashable {
        case general
        case hotkeys
        case advanced
        case about
    }

    @ObservedObject var viewModel: CommandPaletteViewModel
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)? = nil

    @State private var hyperKeyEnabled: Bool = false
    @State private var selectedHyperKeySource: HyperKeyTarget = .capsLock
    @State private var showFavoritesFirst: Bool = true
    @State private var selectedTab: Tab = .general
    @State private var hoveredTab: Tab?
    @State private var hotkeyRows: [HotkeyRow] = []
    @State private var recordingRowId: String?
    @State private var isRecordingShortcut = false

    var body: some View {
        VStack(spacing: 0) {
            tabbedContent
        }
        .frame(width: 760, height: 600)
        .onAppear {
            hyperKeyEnabled = viewModel.settingsStore.hyperKeyEnabled
            selectedHyperKeySource = viewModel.settingsStore.hyperKeySource
            showFavoritesFirst = viewModel.settingsStore.showFavoritesFirst
            Task { await refreshHotkeyRows() }
        }
    }

    private var tabbedContent: some View {
        VStack(spacing: 0) {
            tabsHeader
            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .hotkeys:
                    hotkeysTab
                case .advanced:
                    advancedTab
                case .about:
                    aboutTab
                }
            }
        }
    }

    private var tabsHeader: some View {
        HStack(spacing: 10) {
            tabButton(for: .general, title: "General", icon: "gearshape.fill")
            tabButton(for: .hotkeys, title: "Hotkeys", icon: "keyboard.fill")
            tabButton(for: .advanced, title: "Advanced", icon: "slider.horizontal.3")
            tabButton(for: .about, title: "About", icon: "info.circle.fill")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func tabButton(for tab: Tab, title: String, icon: String) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(width: 78, height: 50)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.09) : (isHovered ? Color.white.opacity(0.045) : Color.clear))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTab = hovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                generalSection
                Divider()
                keyBehaviorSection
                Divider()
                preferencesSection
                Divider()
                themeSection
            }
            .padding()
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("General", systemImage: "gearshape")
                .font(.headline)

            CheckboxRow(title: "Launch Vyra on login", isOn: Binding(
                get: { viewModel.settingsStore.launchOnLogin },
                set: { newValue in
                    viewModel.settingsStore.launchOnLogin = newValue
                    LaunchAtLoginManager.setEnabled(newValue)
                }
            ))

            CheckboxRow(title: "Show in menubar", isOn: Binding(
                get: { viewModel.settingsStore.showInMenuBar },
                set: { newValue in
                    viewModel.settingsStore.showInMenuBar = newValue
                }
            ))

            HStack {
                Text("Text size")
                    .frame(width: 110, alignment: .leading)
                Picker("", selection: Binding(
                    get: { viewModel.settingsStore.textSize },
                    set: { viewModel.settingsStore.textSize = $0 }
                )) {
                    Image(systemName: "textformat.size.smaller")
                        .accessibilityLabel("Default")
                        .tag(SettingsTextSize.default)
                    Image(systemName: "textformat.size.larger")
                        .accessibilityLabel("Large")
                        .tag(SettingsTextSize.large)
                }
                .pickerStyle(.segmented)
                Spacer()
            }

            HStack {
                Text("Appearance")
                    .frame(width: 110, alignment: .leading)
                Picker("", selection: Binding(
                    get: { viewModel.settingsStore.appearance },
                    set: { viewModel.settingsStore.appearance = $0 }
                )) {
                    Text("System").tag(SettingsAppearance.system)
                    Text("Light").tag(SettingsAppearance.light)
                    Text("Dark").tag(SettingsAppearance.dark)
                }
                .pickerStyle(.segmented)
                Spacer()
            }

            HStack {
                Text("Window mode")
                    .frame(width: 110, alignment: .leading)
                Picker("", selection: Binding(
                    get: { viewModel.settingsStore.windowMode },
                    set: { viewModel.settingsStore.windowMode = $0 }
                )) {
                    Text("Default").tag(SettingsWindowMode.default)
                    Text("Compact").tag(SettingsWindowMode.compact)
                }
                .pickerStyle(.segmented)
                Spacer()
            }
        }
    }

    private var hotkeysTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hotkeys")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Reload Apps") {
                    Task { await refreshHotkeyRows() }
                }
                .font(.caption)
            }

            Table(hotkeyRows) {
                TableColumn("Name") { row in
                    Text(row.name)
                        .lineLimit(1)
                }
                .width(min: 260, ideal: 320, max: 420)

                TableColumn("Type") { row in
                    Text(row.kind.displayName)
                        .foregroundStyle(.secondary)
                }
                .width(min: 90, ideal: 110, max: 140)

                TableColumn("Hotkey") { row in
                    HStack(spacing: 8) {
                        Text(shortcutDisplayString(settingsShortcut(for: row), preferHyperSymbol: true))
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(settingsShortcut(for: row) == nil ? .secondary : .primary)
                            .frame(minWidth: 90, alignment: .leading)

                        Button(settingsShortcut(for: row) == nil ? "Record" : "Change") {
                            recordingRowId = row.id
                            isRecordingShortcut = true
                        }
                        .font(.caption)

                        if settingsShortcut(for: row) != nil {
                            Button("Clear") {
                                clearShortcut(for: row)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .sheet(isPresented: $isRecordingShortcut) {
            HotkeyRecorderSheet(
                title: recordingTitle,
                onCancel: {
                    isRecordingShortcut = false
                    recordingRowId = nil
                },
                onRecorded: { shortcut in
                    if let row = hotkeyRows.first(where: { $0.id == recordingRowId }) {
                        setShortcut(shortcut, for: row)
                    }
                    isRecordingShortcut = false
                    recordingRowId = nil
                }
            )
            .frame(width: 420, height: 200)
        }
    }

    private var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                advancedDisplaySection
                Divider()
                navigationBindingsSection
                Divider()
                configSection
            }
            .padding()
        }
    }

    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("About Vyra", systemImage: "info.circle")
                    .font(.headline)

                Text("Vyra is a fast command palette for controlling your Mac—launch apps, run actions, manage windows, and automate workflows.")
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Link("Website", destination: URL(string: "https://vyra.app")!)
                    Link("Built by Rudra", destination: URL(string: "https://rudra.ai")!)
                    HStack(spacing: 8) {
                        Link("X", destination: URL(string: "https://x.com")!)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Link("Rudra website", destination: URL(string: "https://rudra.ai")!)
                    }
                    Text("Thanks for trying Vyra.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
    }

    private var keyBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Behavior", systemImage: "keyboard")
                .font(.headline)

            CheckboxRow(title: "Enable Hyper Key", isOn: $hyperKeyEnabled)
                .onChange(of: hyperKeyEnabled) { _, newValue in
                    viewModel.settingsStore.hyperKeyEnabled = newValue
                }

            if hyperKeyEnabled {
                HStack {
                    Text("Source Key")
                        .frame(width: 100, alignment: .leading)
                    Picker("", selection: $selectedHyperKeySource) {
                        ForEach(HyperKeyTarget.allCases, id: \.self) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedHyperKeySource) { _, newValue in
                        viewModel.settingsStore.hyperKeySource = newValue
                    }
                    Spacer()
                }

                CheckboxRow(title: "Include ⇧ in Hyper", isOn: Binding(
                    get: { viewModel.settingsStore.hyperKeyIncludeShift },
                    set: { viewModel.settingsStore.hyperKeyIncludeShift = $0 }
                ))

                Text("When enabled, the selected key will act as a Hyper key (⌘⌥⌃⇧) when held down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Preferences", systemImage: "gear")
                .font(.headline)

            CheckboxRow(title: "Show favorites first in results", isOn: $showFavoritesFirst)
                .onChange(of: showFavoritesFirst) { _, newValue in
                    viewModel.settingsStore.showFavoritesFirst = newValue
                }

            Button("Clear Recent Items") {
                viewModel.favoritesStore.clearRecents()
            }
            .font(.caption)
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Themes", systemImage: "paintpalette")
                .font(.headline)

            ForEach(viewModel.themeManager.profiles) { profile in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(
                            red: profile.background.red,
                            green: profile.background.green,
                            blue: profile.background.blue
                        ))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.secondary, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.name)
                            .font(.body)
                        Text(profile.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if viewModel.themeManager.currentProfile?.id == profile.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }

                    Button {
                        viewModel.themeManager.setCurrentProfile(profile)
                        viewModel.settingsStore.currentThemeProfileId = profile.id
                    } label: {
                        Text("Select")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !viewModel.themeManager.installedConnectors.isEmpty {
                Divider()
                Text("Connected Apps")
                    .font(.subheadline.weight(.medium))

                ForEach(viewModel.themeManager.installedConnectors, id: \.name) { connector in
                    HStack {
                        Image(systemName: "app.connected.to.app.below.fill")
                            .foregroundStyle(.secondary)
                        Text(connector.name)
                            .font(.body)
                        Spacer()
                        Text("Installed")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Button("Apply Current Theme to All") {
                    Task { await viewModel.themeManager.applyTheme() }
                }
                .font(.caption)
                .disabled(viewModel.themeManager.currentProfile == nil)
            }
        }
    }
}

private struct HotkeyRow: Identifiable, Hashable {
    enum Kind: Hashable {
        case builtin
        case application

        var displayName: String {
            switch self {
            case .builtin: return "Vyra"
            case .application: return "App"
            }
        }
    }

    let id: String
    let name: String
    let kind: Kind
}

private struct CheckboxRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                Text(title)
                    .font(.body)
                    .foregroundStyle(isOn ? .primary : .secondary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private extension SettingsView {
    var recordingTitle: String {
        guard let recordingRowId, let row = hotkeyRows.first(where: { $0.id == recordingRowId }) else {
            return "Record Hotkey"
        }
        return "Record Hotkey for “\(row.name)”"
    }

    func refreshHotkeyRows() async {
        let builtin: [HotkeyRow] = [
            HotkeyRow(id: "vyra:openPalette", name: "Open Palette", kind: .builtin),
            HotkeyRow(id: "vyra:openSettings", name: "Open Settings", kind: .builtin),
            HotkeyRow(id: "vyra:startMacroRecording", name: "Start Macro Recording", kind: .builtin),
            HotkeyRow(id: "vyra:applyTheme", name: "Apply Current Theme", kind: .builtin),
        ]

        let apps = await viewModel.allInstalledApplications()
        let appRows: [HotkeyRow] = apps.map { app in
            let key = app.bundleIdentifier ?? app.url.path
            return HotkeyRow(id: "app:\(key)", name: app.displayName, kind: .application)
        }

        hotkeyRows = (builtin + appRows)
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind.displayName < rhs.kind.displayName }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func settingsShortcut(for row: HotkeyRow) -> KeyboardShortcut? {
        viewModel.settingsStore.hotkeyAssignments[row.id]
    }

    func setShortcut(_ shortcut: KeyboardShortcut, for row: HotkeyRow) {
        var assignments = viewModel.settingsStore.hotkeyAssignments
        assignments[row.id] = shortcut
        viewModel.settingsStore.hotkeyAssignments = assignments
    }

    func clearShortcut(for row: HotkeyRow) {
        var assignments = viewModel.settingsStore.hotkeyAssignments
        assignments[row.id] = nil
        viewModel.settingsStore.hotkeyAssignments = assignments
    }

    func shortcutDisplayString(_ shortcut: KeyboardShortcut?, preferHyperSymbol: Bool) -> String {
        guard let shortcut else { return "Record" }

        let mods = shortcut.modifiers
        let key = keyCodeToString(shortcut.keyCode)

        let cmd: UInt32 = 1 << 0
        let shift: UInt32 = 1 << 1
        let opt: UInt32 = 1 << 2
        let ctrl: UInt32 = 1 << 3

        // Store modifiers in NSEvent-style bits later; for now we treat as a generic bitset.
        // When we wire actual recording, we’ll encode to these bits.
        let isCmd = (mods & cmd) != 0
        let isShift = (mods & shift) != 0
        let isOpt = (mods & opt) != 0
        let isCtrl = (mods & ctrl) != 0

        let wantsHyper = preferHyperSymbol && isCmd && isOpt && isCtrl && (!viewModel.settingsStore.hyperKeyIncludeShift || isShift)

        var parts: [String] = []
        if wantsHyper {
            parts.append("✦")
            if viewModel.settingsStore.hyperKeyIncludeShift == false, isShift {
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

    func keyCodeToString(_ keyCode: UInt32) -> String {
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
        case 49: return "Space"
        default: return "?"
        }
    }
}

private extension SettingsView {
    private var advancedDisplaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Display", systemImage: "display")
                .font(.headline)

            HStack {
                Text("Show Vyra on")
                    .frame(width: 130, alignment: .leading)
                Picker("", selection: Binding(
                    get: { viewModel.settingsStore.showVyraOn },
                    set: { viewModel.settingsStore.showVyraOn = $0 }
                )) {
                    Text("Screen containing mouse").tag(ShowVyraOn.screenContainingMouse)
                    Text("Screen with active window").tag(ShowVyraOn.screenWithActiveWindow)
                    Text("Primary screen").tag(ShowVyraOn.primaryScreen)
                }
                .pickerStyle(.menu)
                Spacer()
            }
        }
    }

    private var navigationBindingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Navigation Bindings", systemImage: "arrow.up.and.down.text.horizontal")
                .font(.headline)

            Picker("Preset", selection: Binding(
                get: { viewModel.settingsStore.navigationBindings },
                set: { viewModel.settingsStore.navigationBindings = $0 }
            )) {
                Text("macOS (⌃N / ⌃P)").tag(NavigationBindingsPreset.macos)
                Text("Vim (⌃J / ⌃K)").tag(NavigationBindingsPreset.vim)
            }
            .pickerStyle(.segmented)
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Config", systemImage: "doc.text")
                .font(.headline)

            Text("Vyra stores settings in a single JSON file you can export and import.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let path = try? viewModel.settingsStore.storagePath() {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button("Export…") { exportConfig() }
                Button("Import…") { importConfig() }
                Spacer()
            }
            .font(.caption)
        }
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vyra-settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try viewModel.settingsStore.exportSettingsData()
                try data.write(to: url, options: .atomic)
            } catch {
                // Best-effort; we’ll surface errors later if needed.
            }
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try viewModel.settingsStore.importSettingsData(data)
                AppModel.shared.registerPaletteHotkeyFromSettings()
            } catch {
                // Best-effort; we’ll surface errors later if needed.
            }
        }
    }
}

private struct HotkeyRecorderSheet: View {
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

private struct HotkeyRecorderView: NSViewRepresentable {
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

private final class RecorderNSView: NSView {
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

        // Ignore if it’s only a modifier key press (keyCode set contains common modifier codes).
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
