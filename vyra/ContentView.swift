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
        windowActions + applications + files
    }

    var body: some View {
        VStack(spacing: 0) {
            DragHandle()
            searchField
            resultsList
        }
        .frame(width: 560, height: 420)
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
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.secondary)

            TextField("Search apps, files, folders, or window actions", text: $viewModel.query)
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
                        if !windowActions.isEmpty {
                            Text("Window")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            ForEach(Array(windowActions.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == offset,
                                    onActivate: { viewModel.activate(item) },
                                    onClose: onClose
                                )
                                .id(offset)
                            }
                        }

                        if !applications.isEmpty {
                            let baseIndex = windowActions.count

                            Text("Apps")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            ForEach(Array(applications.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    onActivate: { viewModel.activate(item) },
                                    onSecondaryAction: item.supportsReveal ? { viewModel.reveal(item) } : nil,
                                    onClose: onClose
                                )
                            }
                        }

                        if !files.isEmpty {
                            let baseIndex = windowActions.count + applications.count

                            Text("Files")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            ForEach(Array(files.enumerated()), id: \.element.id) { offset, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: selectedIndex == baseIndex + offset,
                                    onActivate: { viewModel.activate(item) },
                                    onSecondaryAction: item.supportsReveal ? { viewModel.reveal(item) } : nil,
                                    onClose: onClose
                                )
                            }
                        }
                    }
                }
            }
            .background(ScrollViewConfigurator())
        }
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
    let onActivate: () -> Void
    var onSecondaryAction: (() -> Void)?
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
}

#Preview {
    ContentView(viewModel: CommandPaletteViewModel(), onClose: {})
}
