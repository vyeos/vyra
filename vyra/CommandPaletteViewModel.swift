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

    let favoritesStore = FavoritesStore()
    let settingsStore = SettingsStore()
    let macroRecorder = MacroRecorder()
    let themeManager = ThemeManager()

    private(set) lazy var macroReplayer = MacroReplayer(windowActionService: windowActionService)

    private let fileIndex = FileSearchIndex()
    private let applicationIndex = ApplicationSearchIndex()
    let windowActionService = WindowActionService()
    private let macroStore = MacroStore()
    private let workspace = NSWorkspace.shared
    private var searchTask: Task<Void, Never>?
    private var hasLoaded = false

    var sectionTitle: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Suggestions" : "Matches"
    }

    var statusText: String {
        if isLoading {
            return "Indexing apps, files, shortcuts, and macro storage..."
        }

        return "\(applicationCount) apps • \(fileCount) files • \(macroCount) macros"
    }

    var detailText: String {
        let base = "\(accessibilityStatusText) • Hotkey: ⌃Space"
        guard let lastIndexedAt else { return base }
        return "\(base) • Indexed \(lastIndexedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    /// Check Accessibility status without prompting.
    var isAccessibilityEnabled: Bool {
        windowActionService.checkAccessibility(prompt: false)
    }

    /// Request Accessibility permission (shows system prompt) and return current status.
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let result = windowActionService.requestAccessibility()
        accessibilityStatusText = windowActionService.accessibilityStatusText()
        return result
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
            clearErrorMessage()
            workspace.open(application.url)
            favoritesStore.recordRecent(kind: .application, displayName: application.displayName, path: application.url.path)
            if macroRecorder.isRecording {
                macroRecorder.recordAppLaunch(displayName: application.displayName, bundleIdentifier: application.bundleIdentifier, path: application.url.path)
            }
        case .file(let file):
            clearErrorMessage()
            workspace.open(file.url)
            favoritesStore.recordRecent(kind: .file, displayName: file.displayName, path: file.url.path)
            if macroRecorder.isRecording {
                macroRecorder.recordFileOpen(displayName: file.displayName, path: file.url.path)
            }
        case .windowAction(let action):
            executeWindowAction(action)
        case .appAction(let action):
            clearErrorMessage()
            switch action {
            case .settings:
                AppModel.shared.showSettings()
            }
        case .favorite(let fav):
            clearErrorMessage()
            workspace.open(fav.url)
            favoritesStore.recordRecent(kind: fav.kind, displayName: fav.displayName, path: fav.path)
        case .recent(let recent):
            clearErrorMessage()
            workspace.open(recent.url)
            favoritesStore.recordRecent(kind: recent.kind, displayName: recent.displayName, path: recent.path)
        case .macro(let macro):
            clearErrorMessage()
            macroReplayer.replay(macro: macro)
        case .themeProfile(let profile):
            clearErrorMessage()
            themeManager.setCurrentProfile(profile)
            settingsStore.currentThemeProfileId = profile.id
        case .themeAction:
            clearErrorMessage()
            Task { await themeManager.applyTheme() }
        }
    }

    func reveal(_ item: CommandPaletteItem) {
        switch item.kind {
        case .application(let application):
            workspace.activateFileViewerSelecting([application.url])
        case .file(let file):
            workspace.activateFileViewerSelecting([file.url])
        case .favorite(let fav):
            workspace.activateFileViewerSelecting([fav.url])
        case .windowAction, .recent, .macro, .themeProfile, .themeAction:
            break
        default:
            break
        }
    }

    func toggleFavorite(_ item: CommandPaletteItem) {
        switch item.kind {
        case .application(let app):
            let key = "app:\(app.url.path)"
            if favoritesStore.isFavorite(key: key) {
                favoritesStore.unpin(key: key)
            } else {
                favoritesStore.pinApplication(displayName: app.displayName, bundleIdentifier: app.bundleIdentifier, path: app.url.path)
            }
        case .file(let file):
            let key = "file:\(file.url.path)"
            if favoritesStore.isFavorite(key: key) {
                favoritesStore.unpin(key: key)
            } else {
                favoritesStore.toggleFavorite(FavoriteItem(
                    key: key,
                    kind: file.isDirectory ? .application : .file,
                    displayName: file.displayName,
                    path: file.url.path,
                    pinnedAt: .now
                ))
            }
        case .favorite(let fav):
            favoritesStore.unpin(key: fav.key)
        default:
            break
        }

        Task { await refreshResults() }
    }

    func isFavorite(_ item: CommandPaletteItem) -> Bool {
        switch item.kind {
        case .application(let app):
            return favoritesStore.isFavorite(key: "app:\(app.url.path)")
        case .file(let file):
            return favoritesStore.isFavorite(key: "file:\(file.url.path)")
        case .favorite:
            return true
        default:
            return false
        }
    }

    func executeWindowAction(_ action: WindowAction) {
        do {
            try windowActionService.perform(action)
            clearErrorMessage()
            if macroRecorder.isRecording {
                macroRecorder.recordWindowAction(action)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        accessibilityStatusText = windowActionService.accessibilityStatusText()
    }

    func startMacroRecording() {
        macroRecorder.startRecording()
    }

    func stopMacroRecording() -> MacroDefinition? {
        let steps = macroRecorder.stopRecording()
        guard !steps.isEmpty else { return nil }

        let macro = MacroDefinition(name: "Macro \(Date.now.formatted(date: .abbreviated, time: .shortened))", steps: steps)
        saveMacro(macro)
        return macro
    }
    
    private func clearErrorMessage() {
        guard errorMessage != nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.errorMessage != nil else { return }
            self.errorMessage = nil
        }
    }
    
    func saveMacro(_ macro: MacroDefinition) {
        do {
            var library = try macroStore.loadLibrary()
            if let index = library.macros.firstIndex(where: { $0.id == macro.id }) {
                library.macros[index] = macro
            } else {
                library.macros.append(macro)
            }
            try macroStore.save(library)
            macroCount = library.macros.count
            recentMacros = Array(library.macros.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))
        } catch {
            errorMessage = "Failed to save macro: \(error.localizedDescription)"
        }
    }

    func revealMacroStorage() {
        guard let macroStoragePath else { return }
        workspace.activateFileViewerSelecting([URL(fileURLWithPath: macroStoragePath)])
    }

    func allInstalledApplications() async -> [ApplicationSearchResult] {
        await applicationIndex.allApplications()
    }

    private func load() async {
        isLoading = true
        accessibilityStatusText = windowActionService.accessibilityStatusText()
        defer { isLoading = false }

        do {
            let library = try macroStore.prepareStorage()

            async let rebuildApplications: Void = applicationIndex.rebuild()
            async let rebuildFiles: Void = fileIndex.rebuild()
            async let prepareFavorites: Void = favoritesStore.prepareStorage()
            async let prepareSettings: Void = settingsStore.prepareStorage()
            async let prepareThemes: Void = themeManager.prepareStorage()

            _ = try await (rebuildApplications, rebuildFiles, prepareFavorites, prepareSettings, prepareThemes)

            applicationCount = await applicationIndex.indexedCount()
            fileCount = await fileIndex.indexedCount()
            macroCount = library.macros.count
            macroStoragePath = try macroStore.storageURL().path
            recentMacros = Array(library.macros.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))

            if let themeId = settingsStore.currentThemeProfileId {
                themeManager.setCurrentProfile(ThemeProfile(
                    id: themeId,
                    name: "",
                    background: .black,
                    foreground: .white,
                    cursor: .white,
                    selection: .black
                ))
                if let profile = themeManager.profiles.first(where: { $0.id == themeId }) {
                    themeManager.setCurrentProfile(profile)
                }
            }

            lastIndexedAt = Date()
            errorMessage = nil

            await refreshResults()
        } catch {
            errorMessage = "Setup failed: \(error.localizedDescription)"
        }
    }

    private func refreshResults() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmptyQuery = trimmedQuery.isEmpty

        async let applications = applicationIndex.search(query: query)
        async let files = fileIndex.search(query: query)

        var resultItems: [CommandPaletteItem] = []

        if isEmptyQuery {
            let favoriteItems = favoritesStore.favorites.map { fav in
                CommandPaletteItem(kind: .favorite(fav), score: 15_000)
            }
            let recentItems = favoritesStore.recents.prefix(5).map { recent in
                CommandPaletteItem(kind: .recent(recent), score: 14_000)
            }
            resultItems.append(contentsOf: favoriteItems)
            resultItems.append(contentsOf: recentItems)
        }

        let actionItems = windowActionItems(matching: trimmedQuery)
        let appActionItems = appActionItems(matching: trimmedQuery)
        let applicationItems = await applications.map {
            CommandPaletteItem(kind: .application($0), score: $0.score)
        }
        let fileItems = await files.map {
            CommandPaletteItem(kind: .file($0), score: $0.score)
        }

        if isEmptyQuery || trimmedQuery.lowercased().hasPrefix("macro") || trimmedQuery.lowercased().hasPrefix("run") {
            let macroItems = recentMacros.compactMap { macro -> CommandPaletteItem? in
                if isEmptyQuery { return CommandPaletteItem(kind: .macro(macro), score: 1_500) }
                guard macro.name.localizedCaseInsensitiveContains(trimmedQuery) else { return nil }
                return CommandPaletteItem(kind: .macro(macro), score: 7_000)
            }
            resultItems.append(contentsOf: macroItems)
        }

        if isEmptyQuery || trimmedQuery.lowercased().hasPrefix("theme") {
            let themeItems = themeManager.profiles.map { profile in
                let isSelected = profile.id == themeManager.currentProfile?.id
                return CommandPaletteItem(kind: .themeProfile(profile), score: isSelected ? 3_200 : 3_000)
            }
            resultItems.append(contentsOf: themeItems)

            if !themeManager.installedConnectors.isEmpty {
                resultItems.append(CommandPaletteItem(kind: .themeAction("Apply Theme"), score: 2_900))
            }
        }

        resultItems.append(contentsOf: actionItems)
        resultItems.append(contentsOf: appActionItems)
        resultItems.append(contentsOf: applicationItems)
        resultItems.append(contentsOf: fileItems)

        items = resultItems
            .sorted(by: CommandPaletteItem.sort)
            .prefix(settingsStore.showFavoritesFirst ? 35 : 30)
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

    private func appActionItems(matching query: String) -> [CommandPaletteItem] {
        AppAction.allCases.compactMap { action in
            guard let score = action.matchScore(for: query) else {
                return nil
            }
            return CommandPaletteItem(kind: .appAction(action), score: score)
        }
    }
}
