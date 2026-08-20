//
//  RemindersSettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// One switch per prayer, and a warning when the system will not deliver any of them.
struct RemindersSettingsView: View {
    let viewModel: RemindersSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Form {
            Section {
                ForEach(viewModel.remindablePrayers) { prayer in
                    SettingsToggleRow(titleKey: prayer.labelKey, isOn: binding(for: prayer))
                }
            } header: {
                Text(l10n.string(.settingsRemindersPrayerSection))
            } footer: {
                // `false` and `nil` are different states: refused, and not yet asked. Only the
                // first is worth warning about.
                Text(l10n.string(viewModel.notificationsAllowed == false
                    ? .settingsRemindersDenied
                    : .settingsRemindersFooter))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsRemindersSection))
        // Re-read on each appearance rather than once: permission can be revoked in the Settings
        // app while this app sits in the background.
        .task { await viewModel.loadNotificationStatus() }
    }

    private func binding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { viewModel.isEnabled(prayer) },
            set: { viewModel.setEnabled($0, for: prayer) }
        )
    }
}
