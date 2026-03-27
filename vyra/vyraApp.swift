//
//  vyraApp.swift
//  vyra
//
//  Created by Rudra Patel on 25/03/26.
//

import SwiftUI
//import SwiftData

@main
struct vyraApp: App {
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            Item.self,
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()
    
    var body: some Scene {
        MenuBarExtra(
            "Menubar Example",
            systemImage: "globe.fill"
        ){
            ContentView()
//                .overlay(alignment: .topTrailing) {
//                    Button(
//                        "Quit", systemImage: "xmark.circle.fill"
//                    ) {
//                        NSApp.terminate(nil)
//                    }
//                    .labelStyle(.iconOnly)
//                    .buttonStyle(.plain)
//                    .padding(6)
//                }
                .frame(width: 300, height: 180)
        }
        .menuBarExtraStyle(.window)
//        WindowGroup {
//            ContentView()
//        }
//        .modelContainer(sharedModelContainer)
    }
}
