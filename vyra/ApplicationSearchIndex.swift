//
//  ApplicationSearchIndex.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Foundation

struct ApplicationSearchResult: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let bundleIdentifier: String?
    let score: Int

    var id: URL { url }

    var parentPath: String {
        url.deletingLastPathComponent().path
    }
}

actor ApplicationSearchIndex {
    private struct IndexedApplication: Hashable {
        let url: URL
        let displayName: String
        let normalizedDisplayName: String
        let bundleIdentifier: String
        let normalizedBundleIdentifier: String
    }

    private struct RankedMatch {
        let application: IndexedApplication
        let score: Int
    }

    private let fileManager = FileManager.default
    private var indexedApplications: [IndexedApplication] = []

    func rebuild() throws {
        let urls = try scanApplications()
        indexedApplications = urls.map { url in
            let displayName = url.deletingPathExtension().lastPathComponent
            let bundleIdentifier = Bundle(url: url)?.bundleIdentifier ?? ""
            return IndexedApplication(
                url: url,
                displayName: displayName,
                normalizedDisplayName: Self.normalize(displayName),
                bundleIdentifier: bundleIdentifier,
                normalizedBundleIdentifier: Self.normalize(bundleIdentifier)
            )
        }
    }

    func search(query: String) -> [ApplicationSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return indexedApplications.prefix(12).map {
                ApplicationSearchResult(
                    url: $0.url,
                    displayName: $0.displayName,
                    bundleIdentifier: $0.bundleIdentifier.isEmpty ? nil : $0.bundleIdentifier,
                    score: 500
                )
            }
        }

        let normalizedQuery = Self.normalize(trimmed)

        let matches: [RankedMatch] = indexedApplications.compactMap { application in
            guard let score = Self.matchScore(query: normalizedQuery, application: application) else {
                return nil
            }

            return RankedMatch(application: application, score: score)
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.application.displayName.localizedCaseInsensitiveCompare(rhs.application.displayName) == .orderedAscending
            }
            .prefix(20)
            .map {
                ApplicationSearchResult(
                    url: $0.application.url,
                    displayName: $0.application.displayName,
                    bundleIdentifier: $0.application.bundleIdentifier.isEmpty ? nil : $0.application.bundleIdentifier,
                    score: $0.score
                )
            }
    }

    func indexedCount() -> Int {
        indexedApplications.count
    }

    private func scanApplications() throws -> [URL] {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true),
        ]

        var collected: [URL] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            )

            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension == "app" else { continue }
                collected.append(item)
                enumerator?.skipDescendants()
            }
        }

        return Self.deduplicate(urls: collected)
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

    private static func matchScore(query: String, application: IndexedApplication) -> Int? {
        if application.normalizedDisplayName == query {
            return 10_000
        }

        if application.normalizedDisplayName.hasPrefix(query) {
            return 8_500 - min(application.displayName.count, 200)
        }

        if application.normalizedDisplayName.contains(query) {
            return 7_000 - min(application.displayName.count, 200)
        }

        if !application.normalizedBundleIdentifier.isEmpty && application.normalizedBundleIdentifier.contains(query) {
            return 6_000
        }

        if let distance = fuzzyDistance(needle: query, haystack: application.normalizedDisplayName) {
            return 3_500 - distance
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
