//
//  CalculationSettingsSection.swift
//  ThawabForGod
//

import SwiftUI

/// The calculation method and the Asr madhab.
///
/// These edit the *same* two preferences onboarding asked about, through the same
/// `CalculationSettings` object Home computes from — not a copy of them. That is what makes the
/// change reach the prayer times immediately: Home watches the config it was given and recomputes
/// when it differs, so a reader who changes the method here finds today's times already redrawn
/// when they go back.
struct CalculationSettingsSection: View {
    @Bindable var viewModel: SettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Section {
            SettingsPickerRow(titleKey: .methodLabel, selection: $viewModel.method)
            SettingsPickerRow(titleKey: .madhabLabel, selection: $viewModel.madhab)
        } header: {
            Text(l10n.string(.settingsCalculationSection))
        } footer: {
            Text(l10n.string(.settingsCalculationFooter))
        }
    }
}
