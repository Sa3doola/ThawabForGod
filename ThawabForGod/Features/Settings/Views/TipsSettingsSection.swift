//
//  TipsSettingsSection.swift
//  ThawabForGod
//

import SwiftUI

/// Brings dismissed tips back.
///
/// The footer is the substance of this section, not decoration. TipKit reads its datastore when
/// `Tips.configure` runs at launch, so wiping it mid-session changes nothing on screen — the tips
/// really do come back next launch and not before. Saying so is the alternative to a button that
/// looks broken; see `ResetTipsUseCase` and `TipsService.resetAll()`.
struct TipsSettingsSection: View {
    let viewModel: SettingsViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Section {
            Button {
                viewModel.resetTipsTapped()
            } label: {
                Text(l10n.string(.settingsResetTips))
                    .foregroundStyle(theme.accent)
            }
            // Disabled after the fact rather than hidden: a row that vanishes leaves the reader
            // wondering whether it worked, and the footer below has already answered that.
            .disabled(viewModel.hasResetTips)
        } header: {
            Text(l10n.string(.settingsTipsSection))
        } footer: {
            Text(l10n.string(viewModel.hasResetTips ? .settingsResetTipsDone : .settingsResetTipsFooter))
        }
    }
}
