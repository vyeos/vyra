//
//  ContentView.swift
//  vyra
//
//  Created by Rudra Patel on 25/03/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CommandPaletteViewModel()
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
            await viewModel.load()
            isSearchFieldFocused = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vyra Command Palette")
                .font(.title2.weight(.semibold))
            Text("Search recent and indexed files, then open them instantly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search files, folders, or project names", text: $viewModel.query)
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

            if viewModel.results.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No matching files",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Try a different keyword or wait for indexing to finish.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section(viewModel.sectionTitle) {
                    ForEach(viewModel.results) { result in
                        FileResultRow(
                            result: result,
                            onOpen: { viewModel.open(result) },
                            onReveal: { viewModel.reveal(result) }
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
                if let updatedAt = viewModel.lastIndexedAt {
                    Text("Indexed \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Quit", systemImage: "xmark.circle.fill") {
                NSApp.terminate(nil)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct FileResultRow: View {
    let result: FileSearchResult
    let onOpen: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: result.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(result.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if result.isDirectory {
                        Text("Folder")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }

                    if result.source == .recent {
                        Text("Recent")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }

                Text(result.parentPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Reveal", systemImage: "folder") {
                onReveal()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onOpen)
    }
}

#Preview {
    ContentView()
}
