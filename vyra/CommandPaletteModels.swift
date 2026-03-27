//
//  CommandPaletteModels.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import Foundation

struct CommandPaletteItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case application(ApplicationSearchResult)
        case file(FileSearchResult)
        case windowAction(WindowAction)
        case appAction(AppAction)
        case favorite(FavoriteItem)
        case recent(RecentItem)
        case macro(MacroDefinition)
        case themeProfile(ThemeProfile)
        case themeAction(String)
    }

    enum Icon: Hashable {
        case file(URL)
        case system(String)
    }

    let kind: Kind
    let score: Int

    var id: String {
        switch kind {
        case .application(let application):
            return "app:\(application.url.path)"
        case .file(let file):
            return "file:\(file.url.path)"
        case .windowAction(let action):
            return "action:\(action.rawValue)"
        case .appAction(let action):
            return "appAction:\(action.rawValue)"
        case .favorite(let fav):
            return "favorite:\(fav.key)"
        case .recent(let recent):
            return "recent:\(recent.key)"
        case .macro(let macro):
            return "macro:\(macro.id.uuidString)"
        case .themeProfile(let profile):
            return "theme:\(profile.id.uuidString)"
        case .themeAction(let name):
            return "themeAction:\(name)"
        }
    }

    var title: String {
        switch kind {
        case .application(let application):
            return application.displayName
        case .file(let file):
            return file.displayName
        case .windowAction(let action):
            return action.title
        case .appAction(let action):
            return action.title
        case .favorite(let fav):
            return fav.displayName
        case .recent(let recent):
            return recent.displayName
        case .macro(let macro):
            return macro.name
        case .themeProfile(let profile):
            return profile.name
        case .themeAction(let name):
            return name
        }
    }

    var subtitle: String {
        switch kind {
        case .application(let application):
            return application.parentPath
        case .file(let file):
            return file.parentPath
        case .windowAction(let action):
            return action.subtitle
        case .appAction(let action):
            return action.subtitle
        case .favorite(let fav):
            return fav.path
        case .recent(let recent):
            return "Last used \(recent.lastUsedAt.formatted(.relative(presentation: .named)))"
        case .macro(let macro):
            return "\(macro.steps.count) steps"
        case .themeProfile:
            return "Theme profile"
        case .themeAction:
            return "Apply theme to connected apps"
        }
    }

    var badges: [String] {
        switch kind {
        case .application:
            return ["App"]
        case .file(let file):
            var values: [String] = []
            values.append(file.isDirectory ? "Folder" : "File")
            if file.source == .recent {
                values.append("Recent")
            }
            return values
        case .windowAction:
            return ["Window"]
        case .appAction:
            return ["Vyra"]
        case .favorite(let fav):
            return ["Pinned", fav.kind == .application ? "App" : "File"]
        case .recent:
            return ["Recent"]
        case .macro:
            return ["Macro"]
        case .themeProfile:
            return ["Theme"]
        case .themeAction:
            return ["Theme"]
        }
    }

    var icon: Icon {
        switch kind {
        case .application(let application):
            return .file(application.url)
        case .file(let file):
            return .file(file.url)
        case .windowAction(let action):
            return .system(action.systemImage)
        case .appAction(let action):
            return .system(action.systemImage)
        case .favorite(let fav):
            return .system("pin.fill")
        case .recent:
            return .system("clock.arrow.circlepath")
        case .macro:
            return .system("play.rectangle.fill")
        case .themeProfile:
            return .system("paintpalette.fill")
        case .themeAction:
            return .system("arrow.triangle.2.circlepath")
        }
    }

    var supportsReveal: Bool {
        switch kind {
        case .application, .file, .favorite:
            return true
        case .windowAction, .appAction, .recent, .macro, .themeProfile, .themeAction:
            return false
        }
    }

    static func sort(_ lhs: CommandPaletteItem, _ rhs: CommandPaletteItem) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        if lhs.sortRank != rhs.sortRank {
            return lhs.sortRank < rhs.sortRank
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private var sortRank: Int {
        switch kind {
        case .favorite:
            return -2
        case .recent:
            return -1
        case .windowAction:
            return 0
        case .appAction:
            return 0
        case .application:
            return 1
        case .file:
            return 2
        case .macro:
            return 3
        case .themeProfile:
            return 4
        case .themeAction:
            return 5
        }
    }
}

enum AppAction: String, CaseIterable, Codable, Hashable, Identifiable {
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings:
            return "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .settings:
            return "Open Vyra settings (⌘,)"
        }
    }

    var systemImage: String {
        switch self {
        case .settings:
            return "gearshape"
        }
    }

    var searchTerms: [String] {
        switch self {
        case .settings:
            return ["settings", "preferences", "prefs", "configure"]
        }
    }

    func matchScore(for query: String) -> Int? {
        let normalizedQuery = Self.normalize(query)

        if normalizedQuery.isEmpty {
            return 1_950
        }

        let tokens = [title, subtitle] + searchTerms

        for token in tokens {
            let normalizedToken = Self.normalize(token)
            if normalizedToken == normalizedQuery {
                return 10_000
            }

            if normalizedToken.hasPrefix(normalizedQuery) {
                return 8_000
            }

            if normalizedToken.contains(normalizedQuery) {
                return 6_500
            }
        }

        return nil
    }

    private static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
