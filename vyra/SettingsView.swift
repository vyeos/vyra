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
                        Text(shortcutDisplayString(settingsShortcut(for: row), preferHyperSymbol: true, hyperIncludesShift: viewModel.settingsStore.hyperKeyIncludeShift))
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

    func settingsShortcutDisplay(_ shortcut: KeyboardShortcut?, preferHyperSymbol: Bool) -> String {
        shortcutDisplayString(shortcut, preferHyperSymbol: preferHyperSymbol, hyperIncludesShift: viewModel.settingsStore.hyperKeyIncludeShift)
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
                // Best-effort; we'll surface errors later if needed.
            }
        }
    }
}
