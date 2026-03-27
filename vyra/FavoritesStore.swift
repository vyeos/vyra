//
//  FavoritesStore.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Foundation

struct FavoriteItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case application
        case file
    }

    var id: String { key }
    let key: String
    let kind: Kind
    let displayName: String
    let path: String
    let pinnedAt: Date

    var url: URL { URL(fileURLWithPath: path) }
}

struct RecentItem: Identifiable, Codable, Hashable {
    var id: String { key }
    let key: String
    let kind: FavoriteItem.Kind
    let displayName: String
    let path: String
    var lastUsedAt: Date

    var url: URL { URL(fileURLWithPath: path) }
}

struct FavoritesData: Codable {
    var favorites: [FavoriteItem] = []
    var recents: [RecentItem] = []
}

@MainActor
final class FavoritesStore {
    static let maxRecents = 20

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

    private var data = FavoritesData()

    func prepareStorage() throws {
        let url = try storageURL()
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: url.path) {
            let fileData = try Data(contentsOf: url)
            data = try decoder.decode(FavoritesData.self, from: fileData)
        } else {
            try save()
        }
    }

    var favorites: [FavoriteItem] { data.favorites }

    var recents: [RecentItem] { data.recents.sorted { $0.lastUsedAt > $1.lastUsedAt } }

    func isFavorite(key: String) -> Bool {
        data.favorites.contains { $0.key == key }
    }

    func toggleFavorite(_ item: FavoriteItem) {
        if let index = data.favorites.firstIndex(where: { $0.key == item.key }) {
            data.favorites.remove(at: index)
        } else {
            data.favorites.append(item)
        }
        try? save()
    }

    func pinApplication(displayName: String, bundleIdentifier: String?, path: String) {
        let key = "app:\(path)"
        guard !isFavorite(key: key) else { return }
        data.favorites.append(FavoriteItem(
            key: key,
            kind: .application,
            displayName: displayName,
            path: path,
            pinnedAt: .now
        ))
        try? save()
    }

    func unpin(key: String) {
        data.favorites.removeAll { $0.key == key }
        try? save()
    }

    func recordRecent(kind: FavoriteItem.Kind, displayName: String, path: String) {
        let key = "\(kind.rawValue):\(path)"
        if let index = data.recents.firstIndex(where: { $0.key == key }) {
            data.recents[index].lastUsedAt = .now
        } else {
            data.recents.append(RecentItem(
                key: key,
                kind: kind,
                displayName: displayName,
                path: path,
                lastUsedAt: .now
            ))
        }

        if data.recents.count > Self.maxRecents {
            data.recents.sort { $0.lastUsedAt > $1.lastUsedAt }
            data.recents = Array(data.recents.prefix(Self.maxRecents))
        }

        try? save()
    }

    func clearRecents() {
        data.recents.removeAll()
        try? save()
    }

    private func save() throws {
        let url = try storageURL()
        let encoded = try encoder.encode(data)
        try encoded.write(to: url, options: .atomic)
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
            .appendingPathComponent("favorites.json", isDirectory: false)
    }
}
