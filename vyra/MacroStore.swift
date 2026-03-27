//
//  MacroStore.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Foundation

struct MacroLibrary: Codable, Hashable {
    let schemaVersion: Int
    var macros: [MacroDefinition]

    init(schemaVersion: Int = 1, macros: [MacroDefinition] = []) {
        self.schemaVersion = schemaVersion
        self.macros = macros
    }
}

struct MacroDefinition: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var shortcut: MacroShortcut?
    var steps: [MacroStep]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        shortcut: MacroShortcut? = nil,
        steps: [MacroStep]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.shortcut = shortcut
        self.steps = steps
    }
}

struct MacroShortcut: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
}

struct MacroStep: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case launchApplication
        case openFile
        case windowAction
    }

    var id: UUID
    var kind: Kind
    var displayName: String
    var applicationBundleIdentifier: String?
    var applicationPath: String?
    var targetPath: String?
    var windowAction: WindowAction?
    var delayAfterMilliseconds: Int

    init(
        id: UUID = UUID(),
        kind: Kind,
        displayName: String,
        applicationBundleIdentifier: String? = nil,
        applicationPath: String? = nil,
        targetPath: String? = nil,
        windowAction: WindowAction? = nil,
        delayAfterMilliseconds: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.applicationPath = applicationPath
        self.targetPath = targetPath
        self.windowAction = windowAction
        self.delayAfterMilliseconds = delayAfterMilliseconds
    }

    static func launchApplication(
        displayName: String,
        bundleIdentifier: String?,
        path: String,
        delayAfterMilliseconds: Int = 0
    ) -> MacroStep {
        MacroStep(
            kind: .launchApplication,
            displayName: displayName,
            applicationBundleIdentifier: bundleIdentifier,
            applicationPath: path,
            delayAfterMilliseconds: delayAfterMilliseconds
        )
    }

    static func openFile(
        displayName: String,
        path: String,
        delayAfterMilliseconds: Int = 0
    ) -> MacroStep {
        MacroStep(
            kind: .openFile,
            displayName: displayName,
            targetPath: path,
            delayAfterMilliseconds: delayAfterMilliseconds
        )
    }

    static func windowAction(
        _ action: WindowAction,
        delayAfterMilliseconds: Int = 0
    ) -> MacroStep {
        MacroStep(
            kind: .windowAction,
            displayName: action.title,
            windowAction: action,
            delayAfterMilliseconds: delayAfterMilliseconds
        )
    }
}

@MainActor
final class MacroStore {
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

    func prepareStorage() throws -> MacroLibrary {
        let url = try storageURL()
        let directory = url.deletingLastPathComponent()

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: url.path) {
            let emptyLibrary = MacroLibrary()
            let data = try encoder.encode(emptyLibrary)
            try data.write(to: url, options: .atomic)
            return emptyLibrary
        }

        return try loadLibrary()
    }

    func loadLibrary() throws -> MacroLibrary {
        let url = try storageURL()
        let data = try Data(contentsOf: url)
        return try decoder.decode(MacroLibrary.self, from: data)
    }

    func save(_ library: MacroLibrary) throws {
        let url = try storageURL()
        let data = try encoder.encode(library)
        try data.write(to: url, options: .atomic)
    }

    func storageURL() throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupport
            .appendingPathComponent("Vyra", isDirectory: true)
            .appendingPathComponent("macros.json", isDirectory: false)
    }
}
