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
    @Published private(set) var items: [CommandPaletteItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var applicationCount = 0
    @Published private(set) var fileCount = 0
    @Published private(set) var macroCount = 0
    @Published private(set) var lastIndexedAt: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var macroStoragePath: String?
    @Published private(set) var recentMacros: [MacroDefinition] = []
    @Published private(set) var accessibilityStatusText = ""

    private let fileIndex = FileSearchIndex()
    private let applicationIndex = ApplicationSearchIndex()
    private let windowActionService = WindowActionService()
    private let macroStore = MacroStore()
    private let workspace = NSWorkspace.shared
    private var searchTask: Task<Void, Never>?
    private var hasLoaded = false

    var sectionTitle: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Suggested commands" : "Matches"
    }

    var statusText: String {
        if isLoading {
            return "Indexing apps, files, shortcuts, and macro storage..."
        }

        return "\(applicationCount) apps • \(fileCount) files • \(macroCount) macros"
    }

    var detailText: String {
        let base = "\(accessibilityStatusText) • Hotkey: ⌘⇧Space"
        guard let lastIndexedAt else { return base }
        return "\(base) • Indexed \(lastIndexedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            await refreshResults()
            return
        }

        hasLoaded = true
        await load()
    }

    func openTopResult() {
        guard let topResult = items.first else { return }
        activate(topResult)
    }

    func activate(_ item: CommandPaletteItem) {
        switch item.kind {
        case .application(let application):
            errorMessage = nil
            workspace.open(application.url)
        case .file(let file):
            errorMessage = nil
            workspace.open(file.url)
        case .windowAction(let action):
            executeWindowAction(action)
        }
    }

    func reveal(_ item: CommandPaletteItem) {
        switch item.kind {
        case .application(let application):
            workspace.activateFileViewerSelecting([application.url])
        case .file(let file):
            workspace.activateFileViewerSelecting([file.url])
        case .windowAction:
            break
        }
    }

    func executeWindowAction(_ action: WindowAction) {
        do {
            try windowActionService.perform(action)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        accessibilityStatusText = windowActionService.accessibilityStatusText()
    }

    func revealMacroStorage() {
        guard let macroStoragePath else { return }
        workspace.activateFileViewerSelecting([URL(fileURLWithPath: macroStoragePath)])
    }

    private func load() async {
        isLoading = true
        accessibilityStatusText = windowActionService.accessibilityStatusText()
        defer { isLoading = false }

        do {
            let library = try macroStore.prepareStorage()

            async let rebuildApplications: Void = applicationIndex.rebuild()
            async let rebuildFiles: Void = fileIndex.rebuild()

            _ = try await (rebuildApplications, rebuildFiles)

            applicationCount = await applicationIndex.indexedCount()
            fileCount = await fileIndex.indexedCount()
            macroCount = library.macros.count
            macroStoragePath = try macroStore.storageURL().path
            recentMacros = Array(library.macros.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))
            lastIndexedAt = Date()
            errorMessage = nil

            await refreshResults()
        } catch {
            errorMessage = "Phase 1 setup failed: \(error.localizedDescription)"
        }
    }

    private func refreshResults() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        async let applications = applicationIndex.search(query: query)
        async let files = fileIndex.search(query: query)

        let actionItems = windowActionItems(matching: trimmedQuery)
        let applicationItems = await applications.map {
            CommandPaletteItem(kind: .application($0), score: $0.score)
        }
        let fileItems = await files.map {
            CommandPaletteItem(kind: .file($0), score: $0.score)
        }

        items = (actionItems + applicationItems + fileItems)
            .sorted(by: CommandPaletteItem.sort)
            .prefix(30)
            .map { $0 }
    }

    private func windowActionItems(matching query: String) -> [CommandPaletteItem] {
        WindowAction.allCases.compactMap { action in
            guard let score = action.matchScore(for: query) else {
                return nil
            }

            return CommandPaletteItem(kind: .windowAction(action), score: score)
        }
    }
}
