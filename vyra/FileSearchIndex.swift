//
//  FileSearchIndex.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import Foundation

struct FileSearchResult: Identifiable, Hashable {
    enum Source: Hashable {
        case recent
        case indexed
    }

    let url: URL
    let source: Source
    let score: Int

    var id: URL { url }

    var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    var parentPath: String {
        url.deletingLastPathComponent().path
    }

    var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

actor FileSearchIndex {
    private struct IndexedFile: Hashable {
        let url: URL
        let name: String
        let normalizedName: String
        let path: String
        let normalizedPath: String
    }

    private struct RankedMatch {
        let url: URL
        let score: Int
        let isRecent: Bool
        let displayName: String
    }

    private let fileManager = FileManager.default
    private var indexedFiles: [IndexedFile] = []
    private var recentFiles: [URL] = []

    func rebuild() async throws {
        let recentURLs = await MainActor.run {
            Self.deduplicate(
                urls: NSDocumentController.shared.recentDocumentURLs.filter { Self.shouldKeep(url: $0) }
            )
        }
        let indexedURLs = try scanSearchRoots()
        let uniqueURLs = Self.deduplicate(urls: recentURLs + indexedURLs)

        recentFiles = Self.deduplicate(urls: recentURLs)
        indexedFiles = uniqueURLs.map { url in
            IndexedFile(
                url: url,
                name: url.lastPathComponent,
                normalizedName: Self.normalize(url.lastPathComponent),
                path: url.path,
                normalizedPath: Self.normalize(url.path)
            )
        }
    }

    func search(query: String) -> [FileSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            let recentResults = recentFiles.prefix(8).map {
                FileSearchResult(url: $0, source: .recent, score: 10_000)
            }

            let suggestedResults = indexedFiles
                .filter { !recentFiles.contains($0.url) }
                .prefix(10)
                .map { FileSearchResult(url: $0.url, source: .indexed, score: 100) }

            return recentResults + suggestedResults
        }

        let normalizedQuery = Self.normalize(trimmed)

        let matches: [RankedMatch] = indexedFiles
            .compactMap { file in
                guard let score = Self.matchScore(query: normalizedQuery, file: file) else {
                    return nil
                }

                let isRecent = recentFiles.contains(file.url)
                return RankedMatch(
                    url: file.url,
                    score: score,
                    isRecent: isRecent,
                    displayName: file.name
                )
            }

        return matches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.isRecent != rhs.isRecent { return lhs.isRecent }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .prefix(24)
            .map { item in
                FileSearchResult(
                    url: item.url,
                    source: item.isRecent ? .recent : .indexed,
                    score: item.score
                )
            }
    }

    func indexedCount() -> Int {
        indexedFiles.count
    }

    private func scanSearchRoots() throws -> [URL] {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let candidateRoots = [
            homeDirectory.appendingPathComponent("Desktop", isDirectory: true),
            homeDirectory.appendingPathComponent("Documents", isDirectory: true),
            homeDirectory.appendingPathComponent("Downloads", isDirectory: true),
            homeDirectory.appendingPathComponent("Projects", isDirectory: true),
            homeDirectory.appendingPathComponent("Developer", isDirectory: true),
        ]

        var collected: [URL] = []

        for root in candidateRoots where fileManager.fileExists(atPath: root.path) {
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isPackageKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            )

            var rootCount = 0

            while let item = enumerator?.nextObject() as? URL {
                guard Self.shouldKeep(url: item) else { continue }

                collected.append(item)
                rootCount += 1

                if rootCount >= 700 {
                    break
                }
            }
        }

        return collected
    }

    private static func shouldKeep(url: URL) -> Bool {
        guard url.isFileURL else { return false }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isPackageKey])
        let isDirectory = values?.isDirectory ?? false
        let isRegularFile = values?.isRegularFile ?? false
        let isPackage = values?.isPackage ?? false

        if isPackage { return false }
        if !isDirectory && !isRegularFile { return false }

        let name = url.lastPathComponent
        if name.isEmpty || name.hasPrefix(".") { return false }

        return true
    }

    private static func deduplicate(urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        var ordered: [URL] = []

        for url in urls where seen.insert(url.standardizedFileURL).inserted {
            ordered.append(url.standardizedFileURL)
        }

        return ordered
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private static func matchScore(query: String, file: IndexedFile) -> Int? {
        if file.normalizedName == query {
            return 10_000
        }

        if file.normalizedName.hasPrefix(query) {
            return 8_000 - min(file.name.count, 200)
        }

        if file.normalizedName.contains(query) {
            return 6_500 - min(file.name.count, 200)
        }

        if file.normalizedPath.contains(query) {
            return 5_000 - min(file.path.count, 400)
        }

        if let distance = fuzzyDistance(needle: query, haystack: file.normalizedName) {
            return 3_000 - distance
        }

        return nil
    }

    private static func fuzzyDistance(needle: String, haystack: String) -> Int? {
        guard !needle.isEmpty else { return 0 }

        var currentIndex = haystack.startIndex
        var totalGap = 0

        for character in needle {
            guard let foundIndex = haystack[currentIndex...].firstIndex(of: character) else {
                return nil
            }

            totalGap += haystack.distance(from: currentIndex, to: foundIndex)
            currentIndex = haystack.index(after: foundIndex)
        }

        return totalGap
    }
}
