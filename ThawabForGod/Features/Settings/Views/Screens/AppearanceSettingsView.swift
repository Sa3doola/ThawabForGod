//
//  AppearanceSettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// Accent and light/dark.
///
/// Both write straight through to `ThemeManager`, which is applied once at the root — so the
/// recolour reaches every screen behind this one, not just this form.
struct AppearanceSettingsView: View {
    @Bindable var viewModel: AppearanceSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Form {
            Section {
                AccentSwatchRow(selection: $viewModel.accent)
                SettingsPickerRow(titleKey: .appearanceLabel, selection: $viewModel.appearance)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsAppearanceSection))
    }
}
