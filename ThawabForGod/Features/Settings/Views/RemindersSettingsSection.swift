//
//  RemindersSettingsSection.swift
//  ThawabForGod
//

import SwiftUI

/// One switch per prayer.
///
/// Turning one off is a preference rather than a cancellation: the toggle is written to the
/// store, and the next refresh — which the root triggers when this set changes — rebuilds the
/// window without it. Nothing here talks to the notification centre.
///
/// The footer carries the part the toggles cannot say: that reminders are scheduled ten days
/// ahead rather than indefinitely, and, when permission has been refused, that none of these
/// switches can do anything until it is granted in the Settings app.
struct RemindersSettingsSection: View {
    let viewModel: SettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Section {
            ForEach(viewModel.remindablePrayers) { prayer in
                SettingsToggleRow(titleKey: prayer.labelKey, isOn: binding(for: prayer))
            }
        } header: {
            Text(l10n.string(.settingsRemindersSection))
        } footer: {
            // `false` and `nil` are different states: refused, and not yet asked. Only the first
            // is worth warning about.
            Text(l10n.string(viewModel.notificationsAllowed == false
                ? .settingsRemindersDenied
                : .settingsRemindersFooter))
        }
    }

    private func binding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { viewModel.isReminderEnabled(prayer) },
            set: { viewModel.setReminder($0, for: prayer) }
        )
    }
}
