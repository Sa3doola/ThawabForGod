//
//  PrayerCalculationSettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// The calculation method and the Asr madhab, with a way back to the defaults.
struct PrayerCalculationSettingsView: View {
    @Bindable var viewModel: PrayerCalculationSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Form {
            Section {
                SettingsPickerRow(titleKey: .methodLabel, selection: $viewModel.method)
                SettingsPickerRow(titleKey: .madhabLabel, selection: $viewModel.madhab)
            } footer: {
                Text(l10n.string(.settingsCalculationFooter))
            }

            Section {
                Button(role: .destructive) {
                    viewModel.isConfirmingReset = true
                } label: {
                    Text(l10n.string(.settingsCalculationReset))
                        .foregroundStyle(theme.danger)
                }
                // Disabled rather than hidden when there is nothing to undo: a row that comes and
                // goes is harder to find than one that is simply inert.
                .disabled(!viewModel.hasChoices)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsCalculationSection))
        .confirmationDialog(
            l10n.string(.settingsCalculationResetConfirm),
            isPresented: $viewModel.isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button(l10n.string(.settingsCalculationReset), role: .destructive) {
                viewModel.reset()
            }
        }
    }
}
