//
//  ThemeConnectors.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import Foundation

struct TerminalConnector: ThemeConnector {
    let name = "Terminal"
    let bundleIdentifiers = ["com.apple.Terminal"]

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") != nil
    }

    func apply(_ profile: ThemeProfile) throws {
        let bgHex = profile.background.hexString
        let fgHex = profile.foreground.hexString
        let cursorHex = profile.cursor.hexString
        let selectionHex = profile.selection.hexString

        let script = """
        tell application "Terminal"
            set newSettings to \(createSettingsDict(bg: bgHex, fg: fgHex, cursor: cursorHex, selection: selectionHex, profile: profile))
            set current settings of selected tab of front window to newSettings
        end tell
        """

        try runAppleScript(script)
    }

    func readCurrent() -> ThemeProfile? { nil }

    func backup() throws {
        let backupDir = try backupDirectory()
        let backupPath = backupDir.appendingPathComponent("terminal_backup_\(Int(Date.now.timeIntervalSince1970)).plist")

        if let settings = readTerminalDefaults() {
            try settings.write(to: backupPath, atomically: true, encoding: .utf8)
        }
    }

    func rollback() throws {
        let backupDir = try backupDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
        guard let latestBackup = files.filter({ $0.lastPathComponent.hasPrefix("terminal_backup_") }).sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first else {
            throw ThemeError.noBackupFound
        }
        // Terminal rollback is limited — the backup stores defaults snapshot
    }

    private func createSettingsDict(bg: String, fg: String, cursor: String, selection: String, profile: ThemeProfile) -> String {
        "default settings with name \"Vyra_\(profile.name)\" with contents {background color:\"\(bg)\", cursor color:\"\(cursor)\", normal text color:\"\(fg)\", selected text color:\"\(selection)\"}"
    }

    private func readTerminalDefaults() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.Terminal", "Default Window Settings"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = readPipeToEnd(pipe)
        return String(data: data, encoding: .utf8)
    }

    private func runAppleScript(_ script: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = readPipeToEnd(pipe)
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ThemeError.connectorFailed("Terminal: \(errorString)")
        }
    }

    private func backupDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Vyra/theme-backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

struct VSCodeConnector: ThemeConnector {
    let name = "VS Code"
    let bundleIdentifiers = ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"]

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil
            || NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCodeInsiders") != nil
    }

    func apply(_ profile: ThemeProfile) throws {
        let settingsURL = try userSettingsURL()
        var settings = try readSettings(from: settingsURL)

        let workbenchColorCustomizations = profile.vscodeWorkbenchColors()
        settings["workbench.colorCustomizations"] = workbenchColorCustomizations

        let terminalColors = profile.vscodeTerminalColors()
        var existingTerminalColors = settings["terminal.integrated.ansiColors"] as? [String: String] ?? [:]
        for (key, value) in terminalColors {
            existingTerminalColors[key] = value
        }
        settings["terminal.integrated.ansiColors"] = existingTerminalColors

        try writeSettings(settings, to: settingsURL)
    }

    func readCurrent() -> ThemeProfile? { nil }

    func backup() throws {
        let settingsURL = try userSettingsURL()
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }

        let backupDir = try backupDirectory()
        let backupPath = backupDir.appendingPathComponent("vscode_settings_\(Int(Date.now.timeIntervalSince1970)).json")
        try FileManager.default.copyItem(at: settingsURL, to: backupPath)
    }

    func rollback() throws {
        let settingsURL = try userSettingsURL()
        let backupDir = try backupDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
        guard let latestBackup = files.filter({ $0.lastPathComponent.hasPrefix("vscode_settings_") }).sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first else {
            throw ThemeError.noBackupFound
        }

        if FileManager.default.fileExists(atPath: settingsURL.path) {
            try FileManager.default.removeItem(at: settingsURL)
        }
        try FileManager.default.copyItem(at: latestBackup, to: settingsURL)
    }

    private func userSettingsURL() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let vscodeSupport = home.appendingPathComponent("Library/Application Support/Code/User/settings.json")

        if FileManager.default.fileExists(atPath: vscodeSupport.path) {
            return vscodeSupport
        }

        let insidersPath = home.appendingPathComponent("Library/Application Support/Code - Insiders/User/settings.json")
        if FileManager.default.fileExists(atPath: insidersPath.path) {
            return insidersPath
        }

        return vscodeSupport
    }

    private func readSettings(from url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func writeSettings(_ settings: [String: Any], to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        if let jsonString = String(data: data, encoding: .utf8) {
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func backupDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Vyra/theme-backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

struct ZedConnector: ThemeConnector {
    let name = "Zed"
    let bundleIdentifiers = ["dev.zed.Zed"]

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.zed.Zed") != nil
    }

    func apply(_ profile: ThemeProfile) throws {
        let themesDir = try themesDirectory()
        let themePath = themesDir.appendingPathComponent("vyra-\(profile.name.lowercased()).json")

        let themeJSON = profile.zedThemeJSON()
        try themeJSON.write(to: themePath, atomically: true, encoding: .utf8)
    }

    func readCurrent() -> ThemeProfile? { nil }

    func backup() throws {
        let themesDir = try themesDirectory()
        guard FileManager.default.fileExists(atPath: themesDir.path) else { return }

        let backupDir = try backupDirectory()
        let backupPath = backupDir.appendingPathComponent("zed_themes_\(Int(Date.now.timeIntervalSince1970))")
        try FileManager.default.copyItem(at: themesDir, to: backupPath)
    }

    func rollback() throws {
        let themesDir = try themesDirectory()
        let backupDir = try backupDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
        guard let latestBackup = files.filter({ $0.lastPathComponent.hasPrefix("zed_themes_") }).sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first else {
            throw ThemeError.noBackupFound
        }

        if FileManager.default.fileExists(atPath: themesDir.path) {
            try FileManager.default.removeItem(at: themesDir)
        }
        try FileManager.default.copyItem(at: latestBackup, to: themesDir)
    }

    private func themesDirectory() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".config/zed/themes", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func backupDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Vyra/theme-backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

enum ThemeError: LocalizedError {
    case connectorFailed(String)
    case noBackupFound
    case invalidProfile

    var errorDescription: String? {
        switch self {
        case .connectorFailed(let message): return "Theme connector failed: \(message)"
        case .noBackupFound: return "No backup found for rollback"
        case .invalidProfile: return "Invalid theme profile"
        }
    }
}

extension ThemeColor {
    var hexString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

extension ThemeProfile {
    func vscodeWorkbenchColors() -> [String: String] {
        [
            "editor.background": background.hexString,
            "editor.foreground": foreground.hexString,
            "editorCursor.foreground": cursor.hexString,
            "editor.selectionBackground": selection.hexString,
            "terminal.background": background.hexString,
            "terminal.foreground": foreground.hexString,
            "terminalCursor.foreground": cursor.hexString,
        ]
    }

    func vscodeTerminalColors() -> [String: String] {
        let names = [
            "terminal.ansiBlack", "terminal.ansiRed", "terminal.ansiGreen", "terminal.ansiYellow",
            "terminal.ansiBlue", "terminal.ansiMagenta", "terminal.ansiCyan", "terminal.ansiWhite",
            "terminal.ansiBrightBlack", "terminal.ansiBrightRed", "terminal.ansiBrightGreen", "terminal.ansiBrightYellow",
            "terminal.ansiBrightBlue", "terminal.ansiBrightMagenta", "terminal.ansiBrightCyan", "terminal.ansiBrightWhite",
        ]
        var result: [String: String] = [:]
        for (index, name) in names.enumerated() where index < ansiColors.count {
            result[name] = ansiColors[index].hexString
        }
        return result
    }

    func zedThemeJSON() -> String {
        let ansiNames = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
        var ansiEntries: [String] = []
        for (index, name) in ansiNames.enumerated() where index < ansiColors.count {
            ansiEntries.append("        \"\(name)\": \"\(ansiColors[index].hexString)\"")
            if index + 8 < ansiColors.count {
                ansiEntries.append("        \"bright_\(name)\": \"\(ansiColors[index + 8].hexString)\"")
            }
        }

        return """
        {
          "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
          "name": "Vyra \(name)",
          "author": "Vyra",
          "themes": [
            {
              "name": "Vyra \(name)",
              "appearance": "dark",
              "style": {
                "background": "\(background.hexString)",
                "foreground": "\(foreground.hexString)",
                "cursor": "\(cursor.hexString)",
                "selection": "\(selection.hexString)",
                "terminal": {
        \(ansiEntries.joined(separator: ",\n"))
                }
              }
            }
          ]
        }
        """
    }
}

private func readPipeToEnd(_ pipe: Pipe) -> Data {
    var data = Data()
    while true {
        let chunk = pipe.fileHandleForReading.availableData
        if chunk.isEmpty { break }
        data.append(chunk)
    }
    return data
}
