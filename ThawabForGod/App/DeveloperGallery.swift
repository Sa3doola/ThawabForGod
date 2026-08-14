//
//  DeveloperGallery.swift
//  ThawabForGod
//

import SwiftUI

/// Temporary app root while the foundation layers are built: it puts the design-system and
/// localization galleries side by side so both can be exercised on a device. Delete this,
/// and the galleries' place in the app root, once the first real feature lands.
struct DeveloperGallery: View {
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        TabView {
            DesignSystemGallery()
                .tabItem {
                    Label {
                        Text(l10n.string(.paletteTitle))
                    } icon: {
                        Image(systemName: "paintpalette")
                    }
                }

            LocalizationGallery()
                .tabItem {
                    Label {
                        Text(l10n.string(.languageLabel))
                    } icon: {
                        Image(systemName: "globe")
                    }
                }
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    DeveloperGallery()
        .themed(ThemeManager(settingsStore: settingsStore))
        .localized(
            LocalizationManager(
                settingsStore: settingsStore,
                numberFormatting: LocaleNumberFormattingService()
            )
        )
}
