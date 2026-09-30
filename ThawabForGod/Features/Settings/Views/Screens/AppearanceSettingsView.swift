//
//  AppearanceSettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// Accent, light/dark, and the Home Screen icon.
///
/// The first two write straight through to `ThemeManager`, which is applied once at the root — so
/// the recolour reaches every screen behind this one, not just this form. The icon goes to the
/// system, which confirms the change with an alert of its own.
struct AppearanceSettingsView: View {
    @Bindable var viewModel: AppearanceSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Form {
            Section {
                AccentSwatchRow(selection: $viewModel.accent)
                SettingsPickerRow(titleKey: .appearanceLabel, selection: $viewModel.appearance)
            }

            // Empty on the Mac, which has no alternate icons — no section rather than a row of
            // tiles that could not do anything.
            if !viewModel.iconChoices.isEmpty {
                Section(l10n.string(.appIconLabel)) {
                    AppIconPickerRow(
                        choices: viewModel.iconChoices,
                        selection: viewModel.appIcon,
                        isDisabled: viewModel.isChangingIcon
                    ) { choice in
                        Task { await viewModel.selectIcon(choice) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsAppearanceSection))
        // No actions: the system supplies its own OK, already in the reader's language.
        .alert(l10n.string(.appIconChangeFailed), isPresented: $viewModel.iconChangeFailed) {}
    }
}
