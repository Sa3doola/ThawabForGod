//
//  TipsSettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// Brings dismissed tips back.
///
/// The footer is the substance of this screen, not decoration. TipKit reads its datastore when
/// `Tips.configure` runs at launch, so wiping it mid-session changes nothing on screen — the tips
/// really do come back next launch and not before. Saying so is the alternative to a button that
/// looks broken.
struct TipsSettingsView: View {
    let viewModel: TipsSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Form {
            Section {
                Button {
                    viewModel.resetTipsTapped()
                } label: {
                    Text(l10n.string(.settingsResetTips))
                        .foregroundStyle(theme.accent)
                }
                // Disabled after the fact rather than hidden: a row that vanishes leaves the
                // reader wondering whether it worked, and the footer has already answered that.
                .disabled(viewModel.hasResetTips)
            } footer: {
                Text(
                    l10n.string(
                        viewModel.hasResetTips ? .settingsResetTipsDone : .settingsResetTipsFooter
                    )
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsTipsSection))
    }
}
