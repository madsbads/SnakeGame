//
//  SnakeApp.swift
//  Snake
//
//  Created by Maddie Nevans on 1/24/25.
//

import SwiftUI
import SwiftData

@main
struct SnakeApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GameItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(GameStatus())
        }
        .modelContainer(sharedModelContainer)
    }
}
