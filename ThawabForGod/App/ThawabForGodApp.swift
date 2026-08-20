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

        #if os(macOS)
        // The Mac idiom, and the reason the toolbar gear is `#if os(iOS)`: a Mac user looks for
        // preferences under the app menu and ⌘,, not in the window. The same `SettingsView` fills
        // it, in a `NavigationStack` of its own so the sources screen has somewhere to push to —
        // this scene is not inside the one `RootView` puts up.
        //
        // No `.modelContainer(_:)`: nothing on this screen touches SwiftData.
        Settings {
            @Bindable var coordinator = container.settingsCoordinator

            NavigationStack(path: $coordinator.path) {
                SettingsView(
                    container: container.settings,
                    coordinator: container.settingsCoordinator
                )
            }
            .frame(minWidth: 420, minHeight: 520)
            .themed(container.themeManager)
            .localized(container.localizationManager)
        }
        #endif
    }
}
