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
        }
    }

    var supportsReveal: Bool {
        switch kind {
        case .application, .file:
            return true
        case .windowAction:
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
        case .windowAction:
            return 0
        case .application:
            return 1
        case .file:
            return 2
        }
    }
}
