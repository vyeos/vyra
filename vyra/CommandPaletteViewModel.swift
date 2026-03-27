//
//  CommandPaletteViewModel.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class CommandPaletteViewModel: ObservableObject {
    @Published var query = "" {
        didSet {
            guard oldValue != query else { return }
            searchTask?.cancel()
            searchTask = Task { [weak self] in
                await self?.refreshResults()
            }
        }
    }
    @Published private(set) var results: [FileSearchResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var indexedCount = 0
    @Published private(set) var lastIndexedAt: Date?
    @Published private(set) var errorMessage: String?

    private let index = FileSearchIndex()
    private let workspace = NSWorkspace.shared
    private var searchTask: Task<Void, Never>?

    var sectionTitle: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Recent and suggested files" : "Matching files"
    }

    var statusText: String {
        if isLoading {
            return "Indexing files from Documents, Desktop, Downloads, and Projects..."
        }

        return indexedCount == 0 ? "No files indexed yet" : "\(indexedCount) items indexed"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await index.rebuild()
            indexedCount = await index.indexedCount()
            lastIndexedAt = Date()
            errorMessage = nil
            await refreshResults()
        } catch {
            errorMessage = "Indexing failed: \(error.localizedDescription)"
        }
    }

    func openTopResult() {
        guard let topResult = results.first else { return }
        open(topResult)
    }

    func open(_ result: FileSearchResult) {
        workspace.open(result.url)
    }

    func reveal(_ result: FileSearchResult) {
        workspace.activateFileViewerSelecting([result.url])
    }

    private func refreshResults() async {
        results = await index.search(query: query)
    }
}
