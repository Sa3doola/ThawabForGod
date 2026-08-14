//
//  ThawabForGodApp.swift
//  ThawabForGod
//
//  Created by Saad Sherif on 10/08/2026.
//

import SwiftData // `.modelContainer(_:)`; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import SwiftUI

@main
struct ThawabForGodApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            // Temporary root: the developer galleries, so the design system and localization
            // can be checked on device. The first real feature replaces this.
            DeveloperGallery()
                .themed(container.themeManager)
                .localized(container.localizationManager)
        }
        .modelContainer(container.persistence.container)
    }
}
