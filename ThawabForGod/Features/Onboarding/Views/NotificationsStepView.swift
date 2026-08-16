//
//  NotificationsStepView.swift
//  ThawabForGod
//

import SwiftUI

/// Asks for notification permission, and says plainly that refusing costs nothing.
struct NotificationsStepView: View {
    let viewModel: OnboardingViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        OnboardingScaffold(
            symbol: "bell.badge",
            title: l10n.string(.onboardingNotificationsTitle),
            message: l10n.string(.onboardingNotificationsBody)
        ) {
            switch viewModel.state.notifications {
            case .granted:
                OnboardingConfirmation(message: l10n.string(.onboardingNotificationsGranted))

            case .denied:
                Text(l10n.string(.onboardingNotificationsDeniedBody))
                    .appFont(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

            case .notRequested, .skipped:
                requestButton
            }
        }
    }

    private var requestButton: some View {
        Button {
            Task { await viewModel.requestNotificationPermission() }
        } label: {
            Text(l10n.string(.onboardingNotificationsAllow))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isRequestingPermission)
    }
}
