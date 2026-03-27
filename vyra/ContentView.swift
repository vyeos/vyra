//
//  ContentView.swift
//  vyra
//
//  Created by Rudra Patel on 25/03/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel
    @FocusState private var isSearchFieldFocused: Bool
    @State private var selectedIndex: Int = 0
    let onClose: () -> Void

    private var favorites: [CommandPaletteItem] {
        viewModel.items.filter { if case .favorite = $0.kind { return true }; return false }
    }

    private var recents: [CommandPaletteItem] {
        viewModel.items.filter { if case .recent = $0.kind { return true }; return false }
    }

    private var macros: [CommandPaletteItem] {
        viewModel.items.filter { if case .macro = $0.kind { return true }; return false }
    }

    private var themeItems: [CommandPaletteItem] {
        viewModel.items.filter {
            if case .themeProfile = $0.kind { return true }
            if case .themeAction = $0.kind { return true }
            return false
        }
    }

    private var windowActions: [CommandPaletteItem] {
        viewModel.items.filter { if case .windowAction = $0.kind { return true }; return false }
    }

    private var applications: [CommandPaletteItem] {
        viewModel.items.filter { if case .application = $0.kind { return true }; return false }
    }

    private var files: [CommandPaletteItem] {
        viewModel.items.filter { if case .file = $0.kind { return true }; return false }
    }

    private var effectiveItems: [CommandPaletteItem] {
        var all = favorites
        all.append(contentsOf: recents)
        all.append(contentsOf: macros)
        all.append(contentsOf: themeItems)
        all.append(contentsOf: windowActions)
        all.append(contentsOf: applications)
        all.append(contentsOf: files)
        return all
    }

    var body: some View {
        VStack(spacing: 0) {
            DragHandle()
            searchField
            resultsList
            statusBar
        }
        .frame(width: 580, height: 480)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(keys: ["n"], phases: .down) { _ in
            if NSEvent.modifierFlags.contains(.control) {
                moveSelection(by: 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: ["p"], phases: .down) { _ in
            if NSEvent.modifierFlags.contains(.control) {
                moveSelection(by: -1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if let item = effectiveItems[safe: selectedIndex] {
                viewModel.activate(item)
                onClose()
            }
            return .handled
        }
        .onChange(of: viewModel.query) {
            selectedIndex = 0
        }
    }

    private func moveSelection(by offset: Int) {
        guard !effectiveItems.isEmpty else { return }
        selectedIndex = max(0, min(selectedIndex + offset, effectiveItems.count - 1))
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.macroRecorder.isRecording ? "record.circle.fill" : "magnifyingglass")
                .font(.title)
                .foregroundStyle(viewModel.macroRecorder.isRecording ? .red : .secondary)

            if viewModel.macroRecorder.isRecording {
                Text("Recording macro... \(viewModel.macroRecorder.stepCount) steps")
                    .font(.title)
                    .foregroundStyle(.red)
            } else {
                TextField("Search apps, files, actions, macros, themes", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.title)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        viewModel.openTopResult()
                        onClose()
                    }
                    .onExitCommand {
                        onClose()
                    }
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }

                    if viewModel.items.isEmpty {
                        ContentUnavailableView(
                            "No matching commands",
                            systemImage: "command.circle",
                            description: Text("Try another keyword or wait for indexing to finish.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        if !favorites.isEmpty {
                            sectionHeader("Pinned", icon: "pin.fill")
                            ForEach(Array(favorites.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == offset,
                                    isFavorite: true,
                                    onActivate: { viewModel.activate(item) },
                                    onSecondaryAction: { viewModel.reveal(item) },
                                    onToggleFavorite: { viewModel.toggleFavorite(item) },
                                    onClose: onClose
                                )
                                .id(offset)
                            }
                        }

                        if !recents.isEmpty {
                            let baseIndex = favorites.count
                            sectionHeader("Recent", icon: "clock.arrow.circlepath")
                            ForEach(Array(recents.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    onActivate: { viewModel.activate(item) },
                                    onSecondaryAction: nil,
                                    onClose: onClose
                                )
                                .id(baseIndex + offset)
                            }
                        }

                        if !macros.isEmpty {
                            let baseIndex = favorites.count + recents.count
                            sectionHeader("Macros", icon: "play.rectangle.fill")
                            ForEach(Array(macros.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    onActivate: { viewModel.activate(item) },
                                    onClose: onClose
                                )
                                .id(baseIndex + offset)
                            }
                        }

                        if !themeItems.isEmpty {
                            let baseIndex = favorites.count + recents.count + macros.count
                            sectionHeader("Themes", icon: "paintpalette.fill")
                            ForEach(Array(themeItems.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    onActivate: { viewModel.activate(item) },
                                    onClose: onClose
                                )
                                .id(baseIndex + offset)
                            }
                        }

                        if !windowActions.isEmpty {
                            let baseIndex = favorites.count + recents.count + macros.count + themeItems.count
                            sectionHeader("Window", icon: "macwindow")
                            ForEach(Array(windowActions.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    onActivate: { viewModel.activate(item) },
                                    onClose: onClose
                                )
                                .id(baseIndex + offset)
                            }
                        }

                        if !applications.isEmpty {
                            let baseIndex = favorites.count + recents.count + macros.count + themeItems.count + windowActions.count
                            sectionHeader("Apps", icon: "app.fill")
                            ForEach(Array(applications.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    isFavorite: viewModel.isFavorite(item),
                                    onActivate: { viewModel.activate(item) },
                                    onSecondaryAction: item.supportsReveal ? { viewModel.reveal(item) } : nil,
                                    onToggleFavorite: { viewModel.toggleFavorite(item) },
                                    onClose: onClose
                                )
                                .id(baseIndex + offset)
                            }
                        }

                        if !files.isEmpty {
                            let baseIndex = favorites.count + recents.count + macros.count + themeItems.count + windowActions.count + applications.count
                            sectionHeader("Files", icon: "doc.fill")
                            ForEach(Array(files.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    isFavorite: viewModel.isFavorite(item),
                                    onActivate: { viewModel.activate(item) },
                                    onSecondaryAction: item.supportsReveal ? { viewModel.reveal(item) } : nil,
                                    onToggleFavorite: { viewModel.toggleFavorite(item) },
                                    onClose: onClose
                                )
                                .id(baseIndex + offset)
                            }
                        }
                    }
                }
            }
            .background(ScrollViewConfigurator())
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if viewModel.macroRecorder.isRecording {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                Text("\(viewModel.macroRecorder.stepCount) steps recorded")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let profile = viewModel.themeManager.currentProfile {
                Label(profile.name, systemImage: "paintpalette.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

private struct ScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = FixedScrollerView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class FixedScrollerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureScrollView()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureScrollView()
    }

    private func configureScrollView() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let scrollView = self.findScrollView() {
                scrollView.scrollerStyle = .legacy
            }
        }
    }

    private func findScrollView() -> NSScrollView? {
        var view: NSView? = self.superview
        while view != nil {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            view = view?.superview
        }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct DragHandle: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.tertiary)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 16)
        .contentShape(Rectangle())
        .overlay {
            WindowDragArea()
        }
    }
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragView {
        WindowDragView()
    }

    func updateNSView(_ nsView: WindowDragView, context: Context) {}
}

private class WindowDragView: NSView {
    private var isDragging = false
    private var initialLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        initialLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window = window else { return }
        let currentLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: initialWindowOrigin.x + (currentLocation.x - initialLocation.x),
            y: initialWindowOrigin.y + (currentLocation.y - initialLocation.y)
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        NSCursor.pop()
    }

    override var mouseDownCanMoveWindow: Bool { false }
}

private struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    var isSelected: Bool = false
    var isFavorite: Bool = false
    let onActivate: () -> Void
    var onSecondaryAction: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    var onClose: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            badgesView

            if let onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "pin.fill" : "pin")
                        .font(.subheadline)
                        .foregroundStyle(isFavorite ? .orange : .secondary)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 2)
            }

            if let onSecondaryAction {
                Button {
                    onSecondaryAction()
                } label: {
                    Image(systemName: "folder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.8))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.3))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onActivate()
            onClose?()
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch item.icon {
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
        case .system(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(.primary)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private var badgesView: some View {
        if !item.badges.isEmpty {
            HStack(spacing: 4) {
                ForEach(item.badges, id: \.self) { badge in
                    Text(badge)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

#Preview {
    ContentView(viewModel: CommandPaletteViewModel(), onClose: {})
}
