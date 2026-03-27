//
//  SettingsStore.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Combine
import Foundation

struct KeyBehaviorMapping: Codable, Hashable, Identifiable {
    var id: String { "\(sourceKeyCode)-\(sourceModifiers)" }
    var sourceKeyCode: UInt32
    var sourceModifiers: UInt32
    var targetKeyCode: UInt32
    var targetModifiers: UInt32
    var isEnabled: Bool = true
}

struct KeyboardShortcut: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
}

enum HyperKeyTarget: String, Codable, CaseIterable {
    case capsLock
    case leftCommand
    case rightCommand
    case leftShift
    case rightShift
    case leftOption
    case rightOption
    case leftControl
    case rightControl
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12

    var displayName: String {
        switch self {
        case .capsLock: return "Caps Lock"
        case .leftCommand: return "Left Command"
        case .rightCommand: return "Right Command"
        case .leftShift: return "Left Shift"
        case .rightShift: return "Right Shift"
        case .leftOption: return "Left Option"
        case .rightOption: return "Right Option"
        case .leftControl: return "Left Control"
        case .rightControl: return "Right Control"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        }
    }
}

enum SettingsTextSize: String, Codable, CaseIterable {
    case `default`
    case large
}

enum SettingsAppearance: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

enum SettingsWindowMode: String, Codable, CaseIterable {
    case `default`
    case compact
}

enum ShowVyraOn: String, Codable, CaseIterable {
    case screenContainingMouse
    case screenWithActiveWindow
    case primaryScreen
}

enum NavigationBindingsPreset: String, Codable, CaseIterable {
    case macos
    case vim
}

struct AppSettings: Codable {
    var hyperKeyEnabled: Bool = false
    var hyperKeySource: HyperKeyTarget = .capsLock
    var hyperKeyIncludeShift: Bool = false
    var customMappings: [KeyBehaviorMapping] = []
    var showFavoritesFirst: Bool = true
    var maxSearchResults: Int = 30
    var recentAppsLimit: Int = 5
    var recentFilesLimit: Int = 5
    var currentThemeProfileId: UUID?

    var paletteShortcut: KeyboardShortcut = KeyboardShortcut(keyCode: 49, modifiers: 0) // ⌘⇧Space is applied in hotkey service for now
    var launchOnLogin: Bool = false
    var showInMenuBar: Bool = true
    var textSize: SettingsTextSize = .default
    var appearance: SettingsAppearance = .system
    var windowMode: SettingsWindowMode = .default

    var showVyraOn: ShowVyraOn = .screenContainingMouse
    var navigationBindings: NavigationBindingsPreset = .macos

    var hotkeyAssignments: [String: KeyboardShortcut] = [:]
    var hasCompletedOnboarding: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        hyperKeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hyperKeyEnabled) ?? false
        hyperKeySource = try container.decodeIfPresent(HyperKeyTarget.self, forKey: .hyperKeySource) ?? .capsLock
        hyperKeyIncludeShift = try container.decodeIfPresent(Bool.self, forKey: .hyperKeyIncludeShift) ?? false
        customMappings = try container.decodeIfPresent([KeyBehaviorMapping].self, forKey: .customMappings) ?? []
        showFavoritesFirst = try container.decodeIfPresent(Bool.self, forKey: .showFavoritesFirst) ?? true
        maxSearchResults = try container.decodeIfPresent(Int.self, forKey: .maxSearchResults) ?? 30
        recentAppsLimit = try container.decodeIfPresent(Int.self, forKey: .recentAppsLimit) ?? 5
        recentFilesLimit = try container.decodeIfPresent(Int.self, forKey: .recentFilesLimit) ?? 5
        currentThemeProfileId = try container.decodeIfPresent(UUID.self, forKey: .currentThemeProfileId)

        paletteShortcut = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .paletteShortcut) ?? KeyboardShortcut(keyCode: 49, modifiers: 0)
        launchOnLogin = try container.decodeIfPresent(Bool.self, forKey: .launchOnLogin) ?? false
        showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        textSize = try container.decodeIfPresent(SettingsTextSize.self, forKey: .textSize) ?? .default
        appearance = try container.decodeIfPresent(SettingsAppearance.self, forKey: .appearance) ?? .system
        windowMode = try container.decodeIfPresent(SettingsWindowMode.self, forKey: .windowMode) ?? .default

        showVyraOn = try container.decodeIfPresent(ShowVyraOn.self, forKey: .showVyraOn) ?? .screenContainingMouse
        navigationBindings = try container.decodeIfPresent(NavigationBindingsPreset.self, forKey: .navigationBindings) ?? .macos

        hotkeyAssignments = try container.decodeIfPresent([String: KeyboardShortcut].self, forKey: .hotkeyAssignments) ?? [:]
        // Existing installs without the key: treat as true so they don't get prompted again.
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private var settings = AppSettings()

    var hyperKeyEnabled: Bool {
        get { settings.hyperKeyEnabled }
        set { objectWillChange.send(); settings.hyperKeyEnabled = newValue; try? save() }
    }

    var hyperKeySource: HyperKeyTarget {
        get { settings.hyperKeySource }
        set { objectWillChange.send(); settings.hyperKeySource = newValue; try? save() }
    }

    var hyperKeyIncludeShift: Bool {
        get { settings.hyperKeyIncludeShift }
        set { objectWillChange.send(); settings.hyperKeyIncludeShift = newValue; try? save() }
    }

    var customMappings: [KeyBehaviorMapping] {
        get { settings.customMappings }
        set { objectWillChange.send(); settings.customMappings = newValue; try? save() }
    }

    var showFavoritesFirst: Bool {
        get { settings.showFavoritesFirst }
        set { objectWillChange.send(); settings.showFavoritesFirst = newValue; try? save() }
    }

    var currentThemeProfileId: UUID? {
        get { settings.currentThemeProfileId }
        set { objectWillChange.send(); settings.currentThemeProfileId = newValue; try? save() }
    }

    var launchOnLogin: Bool {
        get { settings.launchOnLogin }
        set { objectWillChange.send(); settings.launchOnLogin = newValue; try? save() }
    }

    var showInMenuBar: Bool {
        get { settings.showInMenuBar }
        set { objectWillChange.send(); settings.showInMenuBar = newValue; try? save() }
    }

    var textSize: SettingsTextSize {
        get { settings.textSize }
        set { objectWillChange.send(); settings.textSize = newValue; try? save() }
    }

    var appearance: SettingsAppearance {
        get { settings.appearance }
        set { objectWillChange.send(); settings.appearance = newValue; try? save() }
    }

    var windowMode: SettingsWindowMode {
        get { settings.windowMode }
        set { objectWillChange.send(); settings.windowMode = newValue; try? save() }
    }

    var showVyraOn: ShowVyraOn {
        get { settings.showVyraOn }
        set { objectWillChange.send(); settings.showVyraOn = newValue; try? save() }
    }

    var navigationBindings: NavigationBindingsPreset {
        get { settings.navigationBindings }
        set { objectWillChange.send(); settings.navigationBindings = newValue; try? save() }
    }

    var hotkeyAssignments: [String: KeyboardShortcut] {
        get { settings.hotkeyAssignments }
        set { objectWillChange.send(); settings.hotkeyAssignments = newValue; try? save() }
    }

    var hasCompletedOnboarding: Bool {
        get { settings.hasCompletedOnboarding }
        set { objectWillChange.send(); settings.hasCompletedOnboarding = newValue; try? save() }
    }

    func prepareStorage() throws {
        let url = try storageURL()
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            settings = try decoder.decode(AppSettings.self, from: data)
        } else {
            try save()
        }
    }

    func storagePath() throws -> String {
        try storageURL().path
    }

    func exportSettingsData() throws -> Data {
        try encoder.encode(settings)
    }

    func importSettingsData(_ data: Data) throws {
        let decoded = try decoder.decode(AppSettings.self, from: data)
        objectWillChange.send()
        settings = decoded
        try save()
    }

    func addMapping(_ mapping: KeyBehaviorMapping) {
        settings.customMappings.append(mapping)
        try? save()
    }

    func removeMapping(_ mapping: KeyBehaviorMapping) {
        settings.customMappings.removeAll { $0.id == mapping.id }
        try? save()
    }

    func toggleMapping(_ mapping: KeyBehaviorMapping) {
        guard let index = settings.customMappings.firstIndex(where: { $0.id == mapping.id }) else { return }
        settings.customMappings[index].isEnabled.toggle()
        try? save()
    }

    private func save() throws {
        let url = try storageURL()
        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }

    fileprivate func storageURL() throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport
            .appendingPathComponent("Vyra", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }
}
