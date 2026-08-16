//
//  OnboardingScaffold.swift
//  ThawabForGod
//

import SwiftUI

/// The shape every onboarding screen shares: a symbol, a title, a body, whatever that step
/// needs in the middle, and the buttons at the bottom.
///
/// Extracted so each step view is only its own content — without it, four screens would each
/// carry the same forty lines of layout, and they would drift.
struct OnboardingScaffold<Content: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .appFont(.title, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Text(message)
                    .appFont(.body)
                    .foregroundStyle(theme.textSecondary)
            }
            // Long sentences in either language must wrap, never shrink to fit.
            .fixedSize(horizontal: false, vertical: true)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Multi-line text aligns to the reading direction, which is what mirrors it for Arabic.
        .multilineTextAlignment(.leading)
    }
}

/// A settled outcome — permission granted, coordinates saved — shown in place of the button
/// that produced it.
struct OnboardingConfirmation: View {
    let message: String

    @Environment(\.theme) private var theme

    var body: some View {
        Label {
            Text(message)
                .appFont(.callout, weight: .medium)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
        }
        .foregroundStyle(theme.success)
        .accessibilityElement(children: .combine)
    }
}
