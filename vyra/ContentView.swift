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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            searchField
            resultsList
            footer
        }
        .padding(16)
        .frame(width: 560, height: 520)
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
        .task {
            await viewModel.loadIfNeeded()
            isSearchFieldFocused = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vyra Command Palette")
                .font(.title2.weight(.semibold))
            Text("Launch apps, open files, run window actions, and prepare macros from one surface.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.1))
        }
    }

    private var resultsList: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if viewModel.items.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No matching commands",
                        systemImage: "command.circle",
                        description: Text("Try another keyword or wait for indexing to finish.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section(viewModel.sectionTitle) {
                    ForEach(viewModel.items) { item in
                        CommandPaletteRow(
                            item: item,
                            onActivate: { viewModel.activate(item) },
                            onSecondaryAction: item.supportsReveal ? { viewModel.reveal(item) } : nil
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.statusText)
                    .font(.footnote.weight(.medium))
                Text(viewModel.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Quit", systemImage: "xmark.circle.fill") {
                NSApp.terminate(nil)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let onActivate: () -> Void
    let onSecondaryAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    ForEach(item.badges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let onSecondaryAction {
                Button("Reveal", systemImage: "folder") {
                    onSecondaryAction()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onActivate)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.icon {
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
        case .system(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.primary)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

#Preview {
    ContentView(viewModel: CommandPaletteViewModel())
}
