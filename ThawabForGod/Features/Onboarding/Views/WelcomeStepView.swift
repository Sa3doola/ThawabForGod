//
//  WelcomeStepView.swift
//  ThawabForGod
//

import SwiftUI

/// What the app is, and the two promises it makes: it works offline, and location never
/// leaves the device. Both are stated here, before anything is asked for.
struct WelcomeStepView: View {
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        OnboardingScaffold(
            symbol: "moon.stars",
            title: l10n.string(.onboardingWelcomeTitle),
            message: l10n.string(.onboardingWelcomeBody)
        ) {
            VStack(alignment: .leading, spacing: 16) {
                PromiseRow(
                    symbol: "wifi.slash",
                    title: l10n.string(.onboardingOfflineTitle),
                    message: l10n.string(.onboardingOfflineBody)
                )
                PromiseRow(
                    symbol: "lock.shield",
                    title: l10n.string(.onboardingPrivacyTitle),
                    message: l10n.string(.onboardingPrivacyBody)
                )
            }
            .padding(.top, 4)
        }
    }
}

private struct PromiseRow: View {
    let symbol: String
    let title: String
    let message: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)
                Text(message)
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
