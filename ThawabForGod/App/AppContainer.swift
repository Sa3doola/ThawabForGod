//
//  AppContainer.swift
//  ThawabForGod
//

import Foundation

/// Composition root. The only place concrete implementations are constructed — everything
/// else depends on protocols and receives them through init or the environment.
@MainActor
final class AppContainer {
    let settingsStore: any SettingsStore
    let numberFormatting: any NumberFormattingService
    let persistence: PersistenceController
    let themeManager: ThemeManager
    let localizationManager: LocalizationManager
    let bookmarkRepository: any BookmarkRepository
    let httpClient: any HTTPClient
    let reachability = ReachabilityMonitor()

    init(
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        numberFormatting: any NumberFormattingService = LocaleNumberFormattingService(),
        persistence: PersistenceController = .makeDefault(),
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.settingsStore = settingsStore
        self.numberFormatting = numberFormatting
        self.persistence = persistence
        self.httpClient = httpClient
        self.themeManager = ThemeManager(settingsStore: settingsStore)
        self.localizationManager = LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: numberFormatting
        )
        self.bookmarkRepository = SwiftDataBookmarkRepository(
            modelContainer: persistence.container
        )

        // Networking is optional, but knowing whether it is available is cheap and lets the
        // UI gate online-only actions from launch.
        reachability.start()
    }
}
