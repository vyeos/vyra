//
//  SettingsStore.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Foundation

struct KeyBehaviorMapping: Codable, Hashable, Identifiable {
    var id: String { "\(sourceKeyCode)-\(sourceModifiers)" }
    var sourceKeyCode: UInt32
    var sourceModifiers: UInt32
    var targetKeyCode: UInt32
    var targetModifiers: UInt32
    var isEnabled: Bool = true
}

enum HyperKeyTarget: String, Codable, CaseIterable {
    case capsLock
    case rightCommand
    case rightOption
    case rightControl
    case f18

    var displayName: String {
        switch self {
        case .capsLock: return "Caps Lock"
        case .rightCommand: return "Right Command"
        case .rightOption: return "Right Option"
        case .rightControl: return "Right Control"
        case .f18: return "F18"
        }
    }
}

struct AppSettings: Codable {
    var hyperKeyEnabled: Bool = false
    var hyperKeySource: HyperKeyTarget = .capsLock
    var customMappings: [KeyBehaviorMapping] = []
    var showFavoritesFirst: Bool = true
    var maxSearchResults: Int = 30
    var recentAppsLimit: Int = 5
    var recentFilesLimit: Int = 5
    var currentThemeProfileId: UUID?
}

@MainActor
final class SettingsStore {
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
        set { settings.hyperKeyEnabled = newValue; try? save() }
    }

    var hyperKeySource: HyperKeyTarget {
        get { settings.hyperKeySource }
        set { settings.hyperKeySource = newValue; try? save() }
    }

    var customMappings: [KeyBehaviorMapping] {
        get { settings.customMappings }
        set { settings.customMappings = newValue; try? save() }
    }

    var showFavoritesFirst: Bool {
        get { settings.showFavoritesFirst }
        set { settings.showFavoritesFirst = newValue; try? save() }
    }

    var currentThemeProfileId: UUID? {
        get { settings.currentThemeProfileId }
        set { settings.currentThemeProfileId = newValue; try? save() }
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

    private func storageURL() throws -> URL {
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
