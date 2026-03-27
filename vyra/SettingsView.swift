//
//  SettingsView.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)? = nil

    @State private var hyperKeyEnabled: Bool = false
    @State private var selectedHyperKeySource: HyperKeyTarget = .capsLock
    @State private var showFavoritesFirst: Bool = true
    @State private var showKeyMappingSheet = false
    @State private var newSourceKey: String = ""
    @State private var newTargetKey: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 520, height: 440)
        .onAppear {
            hyperKeyEnabled = viewModel.settingsStore.hyperKeyEnabled
            selectedHyperKeySource = viewModel.settingsStore.hyperKeySource
            showFavoritesFirst = viewModel.settingsStore.showFavoritesFirst
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.title2.weight(.semibold))
            Spacer()
            Button("Done") {
                if let onDone {
                    onDone()
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                keyBehaviorSection
                Divider()
                preferencesSection
                Divider()
                themeSection
            }
            .padding()
        }
    }

    private var footer: some View {
        HStack {
            Text("Changes are saved automatically")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var keyBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Behavior", systemImage: "keyboard")
                .font(.headline)

            Toggle("Enable Hyper Key", isOn: $hyperKeyEnabled)
                .toggleStyle(.switch)
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

                Text("When enabled, the selected key will act as a Hyper key (⌘⌥⌃⇧) when held down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Label("Custom Mappings", systemImage: "arrow.triangle.swap")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Add Mapping") {
                    showKeyMappingSheet = true
                }
                .font(.caption)
            }

            if viewModel.settingsStore.customMappings.isEmpty {
                Text("No custom key mappings configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(viewModel.settingsStore.customMappings) { mapping in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { mapping.isEnabled },
                            set: { _ in viewModel.settingsStore.toggleMapping(mapping) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()

                        Text("Key \(mapping.sourceKeyCode)")
                            .font(.caption)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Key \(mapping.targetKeyCode)")
                            .font(.caption)

                        Spacer()

                        Button {
                            viewModel.settingsStore.removeMapping(mapping)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Preferences", systemImage: "gear")
                .font(.headline)

            Toggle("Show favorites first in results", isOn: $showFavoritesFirst)
                .toggleStyle(.switch)
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
