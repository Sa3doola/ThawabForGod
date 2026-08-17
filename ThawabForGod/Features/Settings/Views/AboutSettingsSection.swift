//
//  AboutSettingsSection.swift
//  ThawabForGod
//

import SwiftUI

/// The version, and the way through to what the app is built from.
struct AboutSettingsSection: View {
    let viewModel: SettingsViewModel
    let onShowSources: () -> Void

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Section {
            SettingsValueRow(titleKey: .settingsVersionLabel, value: viewModel.versionText)
            SettingsDisclosureRow(titleKey: .settingsSourcesTitle, action: onShowSources)
        } header: {
            Text(l10n.string(.settingsAboutSection))
        } footer: {
            Text(l10n.string(.settingsSourcesFooter))
        }
    }
}
