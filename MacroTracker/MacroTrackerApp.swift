//
//  MacroTrackerApp.swift
//  MacroTracker
//

import SwiftUI
import SwiftData

@main
struct MacroTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            FoodItem.self,
            DailyEntry.self,
            DailyHistory.self,
            WorkoutEntry.self
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
                // The magic happens here:
                .onAppear {
                    DatabaseSeeder.seed(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
