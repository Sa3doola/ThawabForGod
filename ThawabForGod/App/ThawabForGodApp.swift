//
//  ThawabForGodApp.swift
//  ThawabForGod
//
//  Created by Saad Sherif on 10/08/2026.
//

import SwiftUI
import SwiftData

@main
struct ThawabForGodApp: App {
    @State private var container = AppContainer()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            // Temporary root: the design-system gallery, so the palette and type scale can be
            // checked on device. The real root returns with the persistence step.
            DesignSystemGallery()
                .themed(container.themeManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
