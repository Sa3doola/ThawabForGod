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
            RootView(container: container)
                .themed(container.themeManager)
                .localized(container.localizationManager)
        }
        .modelContainer(container.persistence.container)
    }
}
