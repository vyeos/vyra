//
//  ContentView.swift
//  vyra
//
//  Created by Rudra Patel on 25/03/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var textInput: String = ""
    
    var body: some View{
        VStack(alignment: .leading) {
            Text("Add you text below")
                .foregroundStyle(.secondary)
            TextEditor(text: $textInput)
                .padding(.vertical, 4)
                .scrollContentBackground(.hidden)
                .background(.thinMaterial)
            Button(
                "Copy uppercased result",
                systemImage: "square.on.square"
            ) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(
                    textInput.uppercased(), forType: .string
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding()
        Button(
            "Quit", systemImage: "xmark.circle.fill"
        ) {
            NSApp.terminate(nil)
        }
//        .buttonStyle(.plain)
    }
//    @Environment(\.modelContext) private var modelContext
//    @Query private var items: [Item]
//
//    var body: some View {
//        NavigationSplitView {
//            List {
//                ForEach(items) { item in
//                    NavigationLink {
//                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
//                    } label: {
//                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
//                    }
//                }
//                .onDelete(perform: deleteItems)
//            }
//            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
//            .toolbar {
//                ToolbarItem {
//                    Button(action: addItem) {
//                        Label("Add Item", systemImage: "plus")
//                    }
//                }
//            }
//        } detail: {
//            Text("Select an item")
//        }
//    }
//
//    private func addItem() {
//        withAnimation {
//            let newItem = Item(timestamp: Date())
//            modelContext.insert(newItem)
//        }
//    }
//
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(items[index])
//            }
//        }
//    }
}

#Preview {
    ContentView()
    //    ContentView()
    //        .modelContainer(for: Item.self, inMemory: true)
    
}
