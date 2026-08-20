//
//  AboutView.swift
//  ThawabForGod
//

import SwiftUI

/// What the app is, and the way through to what it is built from.
struct AboutView: View {
    let viewModel: AboutViewModel
    let onShowSources: () -> Void

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Form {
            Section {
                SettingsValueRow(titleKey: .settingsVersionLabel, value: viewModel.versionText)
            }

            Section {
                SettingsDisclosureRow(titleKey: .settingsSourcesTitle, action: onShowSources)
            } footer: {
                Text(l10n.string(.settingsSourcesFooter))
            }

            Section {
                Text(l10n.string(.settingsPrivacyNote))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsAboutSection))
    }
}
