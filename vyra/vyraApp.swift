//
//  vyraApp.swift
//  vyra
//
//  Created by Rudra Patel on 25/03/26.
//

import SwiftUI
// import SwiftData

@main
struct vyraApp: App {
    var body: some Scene {
        MenuBarExtra(
            "Vyra",
            systemImage: "command.square"
        ) {
            ContentView()
                .frame(width: 560, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}
