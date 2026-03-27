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

    var body: some View {
        VStack(spacing: 8) {
            searchField
            resultsList
        }
        .padding(0)
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            isSearchFieldFocused = true
            await viewModel.loadIfNeeded()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search apps, files, folders, or window actions", text: $viewModel.query)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    viewModel.openTopResult()
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
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
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
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        ForEach(windowActions) { item in
                            CommandPaletteRow(item: item, onActivate: { viewModel.activate(item) })
                        }
                    }

                    if !applications.isEmpty {
                        Text("Apps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        ForEach(applications) { item in
                            CommandPaletteRow(item: item, onActivate: { viewModel.activate(item) }, onSecondaryAction: item.supportsReveal ? { viewModel.reveal(item) } : nil)
                        }
                    }

                    if !files.isEmpty {
                        Text("Files")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        ForEach(files) { item in
                            CommandPaletteRow(item: item, onActivate: { viewModel.activate(item) }, onSecondaryAction: item.supportsReveal ? { viewModel.reveal(item) } : nil)
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let onActivate: () -> Void
    var onSecondaryAction: (() -> Void)?

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
        .contentShape(Rectangle())
        .onTapGesture(perform: onActivate)
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