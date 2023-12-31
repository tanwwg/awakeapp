//
//  wakeappApp.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 26/12/23.
//

import SwiftUI
import SwiftData

@main
struct wakeappApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WakeHost.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        Window("Wake app", id: "main") {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
