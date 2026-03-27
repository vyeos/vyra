//
//  ThemeManager.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import Combine
import Foundation

struct ThemeColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let black = ThemeColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = ThemeColor(red: 1, green: 1, blue: 1, alpha: 1)
}

struct ThemeProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var background: ThemeColor
    var foreground: ThemeColor
    var cursor: ThemeColor
    var selection: ThemeColor
    var ansiColors: [ThemeColor]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        background: ThemeColor,
        foreground: ThemeColor,
        cursor: ThemeColor,
        selection: ThemeColor,
        ansiColors: [ThemeColor] = ThemeProfile.defaultAnsiColors,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.background = background
        self.foreground = foreground
        self.cursor = cursor
        self.selection = selection
        self.ansiColors = ansiColors.count >= 16 ? ansiColors : Self.defaultAnsiColors
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let defaultAnsiColors: [ThemeColor] = [
        ThemeColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1),
        ThemeColor(red: 0.753, green: 0.224, blue: 0.169, alpha: 1),
        ThemeColor(red: 0.522, green: 0.757, blue: 0.255, alpha: 1),
        ThemeColor(red: 0.953, green: 0.686, blue: 0.247, alpha: 1),
        ThemeColor(red: 0.349, green: 0.651, blue: 0.878, alpha: 1),
        ThemeColor(red: 0.710, green: 0.408, blue: 0.773, alpha: 1),
        ThemeColor(red: 0.388, green: 0.741, blue: 0.761, alpha: 1),
        ThemeColor(red: 0.808, green: 0.788, blue: 0.757, alpha: 1),
        ThemeColor(red: 0.478, green: 0.478, blue: 0.478, alpha: 1),
        ThemeColor(red: 0.925, green: 0.380, blue: 0.337, alpha: 1),
        ThemeColor(red: 0.690, green: 0.894, blue: 0.451, alpha: 1),
        ThemeColor(red: 0.976, green: 0.839, blue: 0.455, alpha: 1),
        ThemeColor(red: 0.537, green: 0.749, blue: 0.961, alpha: 1),
        ThemeColor(red: 0.839, green: 0.569, blue: 0.882, alpha: 1),
        ThemeColor(red: 0.541, green: 0.886, blue: 0.894, alpha: 1),
        ThemeColor(red: 0.933, green: 0.914, blue: 0.878, alpha: 1),
    ]

    static func dark(name: String = "Dark") -> ThemeProfile {
        ThemeProfile(
            name: name,
            background: ThemeColor(red: 0.118, green: 0.118, blue: 0.137, alpha: 1),
            foreground: ThemeColor(red: 0.878, green: 0.859, blue: 0.820, alpha: 1),
            cursor: ThemeColor(red: 0.878, green: 0.859, blue: 0.820, alpha: 1),
            selection: ThemeColor(red: 0.235, green: 0.235, blue: 0.275, alpha: 1)
        )
    }

    static func light(name: String = "Light") -> ThemeProfile {
        ThemeProfile(
            name: name,
            background: ThemeColor(red: 0.957, green: 0.945, blue: 0.914, alpha: 1),
            foreground: ThemeColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1),
            cursor: ThemeColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1),
            selection: ThemeColor(red: 0.835, green: 0.820, blue: 0.784, alpha: 1)
        )
    }

    static func monokai(name: String = "Monokai") -> ThemeProfile {
        ThemeProfile(
            name: name,
            background: ThemeColor(red: 0.145, green: 0.161, blue: 0.125, alpha: 1),
            foreground: ThemeColor(red: 0.976, green: 0.973, blue: 0.945, alpha: 1),
            cursor: ThemeColor(red: 0.976, green: 0.973, blue: 0.945, alpha: 1),
            selection: ThemeColor(red: 0.275, green: 0.294, blue: 0.243, alpha: 1),
            ansiColors: [
                ThemeColor(red: 0.267, green: 0.275, blue: 0.231, alpha: 1),
                ThemeColor(red: 0.937, green: 0.310, blue: 0.439, alpha: 1),
                ThemeColor(red: 0.690, green: 0.871, blue: 0.314, alpha: 1),
                ThemeColor(red: 0.976, green: 0.957, blue: 0.388, alpha: 1),
                ThemeColor(red: 0.408, green: 0.706, blue: 0.976, alpha: 1),
                ThemeColor(red: 0.741, green: 0.471, blue: 0.957, alpha: 1),
                ThemeColor(red: 0.404, green: 0.933, blue: 0.749, alpha: 1),
                ThemeColor(red: 0.976, green: 0.973, blue: 0.945, alpha: 1),
                ThemeColor(red: 0.514, green: 0.525, blue: 0.459, alpha: 1),
                ThemeColor(red: 0.937, green: 0.310, blue: 0.439, alpha: 1),
                ThemeColor(red: 0.690, green: 0.871, blue: 0.314, alpha: 1),
                ThemeColor(red: 0.976, green: 0.957, blue: 0.388, alpha: 1),
                ThemeColor(red: 0.408, green: 0.706, blue: 0.976, alpha: 1),
                ThemeColor(red: 0.741, green: 0.471, blue: 0.957, alpha: 1),
                ThemeColor(red: 0.404, green: 0.933, blue: 0.749, alpha: 1),
                ThemeColor(red: 0.976, green: 0.973, blue: 0.945, alpha: 1),
            ]
        )
    }

    static func builtinProfiles() -> [ThemeProfile] {
        [.dark(), .light(), .monokai()]
    }
}

struct ThemeApplyResult: Identifiable {
    let id = UUID()
    let connectorName: String
    let success: Bool
    let error: String?
}

protocol ThemeConnector {
    var name: String { get }
    var bundleIdentifiers: [String] { get }
    var isInstalled: Bool { get }
    func apply(_ profile: ThemeProfile) throws
    func readCurrent() -> ThemeProfile?
    func backup() throws
    func rollback() throws
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var profiles: [ThemeProfile] = []
    @Published private(set) var currentProfileId: UUID?
    @Published private(set) var connectors: [ThemeConnector] = []
    @Published private(set) var lastApplyResults: [ThemeApplyResult] = []
    @Published private(set) var isApplying = false

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var currentProfile: ThemeProfile? {
        guard let id = currentProfileId else { return nil }
        return profiles.first { $0.id == id }
    }

    var installedConnectors: [ThemeConnector] {
        connectors.filter { $0.isInstalled }
    }

    func prepareStorage() throws {
        let url = try storageURL()
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            let stored = try decoder.decode([ThemeProfile].self, from: data)
            profiles = stored
        }

        if profiles.isEmpty {
            profiles = ThemeProfile.builtinProfiles()
            try saveProfiles()
        }

        connectors = [
            TerminalConnector(),
            VSCodeConnector(),
            ZedConnector(),
        ]
    }

    func setCurrentProfile(_ profile: ThemeProfile) {
        currentProfileId = profile.id
    }

    func addProfile(_ profile: ThemeProfile) throws {
        profiles.append(profile)
        try saveProfiles()
    }

    func updateProfile(_ profile: ThemeProfile) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var updated = profile
        updated.updatedAt = .now
        profiles[index] = updated
        try saveProfiles()
    }

    func deleteProfile(_ profile: ThemeProfile) throws {
        profiles.removeAll { $0.id == profile.id }
        if currentProfileId == profile.id {
            currentProfileId = nil
        }
        try saveProfiles()
    }

    func applyTheme(to connectorNames: Set<String>? = nil) async {
        guard let profile = currentProfile else {
            lastApplyResults = [ThemeApplyResult(connectorName: "All", success: false, error: "No theme profile selected")]
            return
        }

        isApplying = true
        defer { isApplying = false }

        var results: [ThemeApplyResult] = []
        let targets = connectorNames == nil
            ? installedConnectors
            : installedConnectors.filter { connectorNames!.contains($0.name) }

        for connector in targets {
            do {
                try connector.backup()
                try connector.apply(profile)
                results.append(ThemeApplyResult(connectorName: connector.name, success: true, error: nil))
            } catch {
                do {
                    try connector.rollback()
                } catch {
                    // rollback failed, report both
                }
                results.append(ThemeApplyResult(connectorName: connector.name, success: false, error: error.localizedDescription))
            }
        }

        lastApplyResults = results
    }

    private func saveProfiles() throws {
        let url = try storageURL()
        let data = try encoder.encode(profiles)
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
            .appendingPathComponent("themes.json", isDirectory: false)
    }
}
