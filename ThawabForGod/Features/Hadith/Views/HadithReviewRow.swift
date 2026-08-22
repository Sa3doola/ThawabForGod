//
//  HadithReviewRow.swift
//  ThawabForGod
//

import SwiftUI

/// How many narrations are due for review, and the way into the session.
///
/// The one place the memorization deck surfaces outside its own screen, and it earns that place
/// by being the thing that makes spaced repetition work at all: intervals are useless if nothing
/// tells the reader today is the day. **Consistency beats cramming** is the pedagogy the plan
/// rests on, and a row that says "3 due" every morning is what consistency looks like in an app.
struct HadithReviewRow: View {
    /// How many cards are due now. Zero is a real value — see `label`.
    let due: Int
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private var hasDue: Bool { due > 0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: hasDue ? "brain.head.profile.fill" : "checkmark")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(hasDue ? theme.accent : theme.success)
                    .frame(width: 32, height: 32)
                    .background(
                        (hasDue ? theme.accent : theme.success).opacity(0.12),
                        in: .circle
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.string(.hadithMemorizeTitle))
                        .appFont(.footnote)
                        .foregroundStyle(theme.textSecondary)

                    label
                }

                Spacer(minLength: 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// `3 due`, or "nothing today" when the deck is caught up.
    ///
    /// Both are worth saying, and they are not the same sentence. A reader who has finished for
    /// the day has *done* something; a row that simply showed `0` would read like a fault.
    @ViewBuilder
    private var label: some View {
        if hasDue {
            HStack(spacing: 4) {
                Text(l10n.string(due))
                Text(l10n.string(.hadithMemorizeDueLabel))
            }
            .appFont(.headline)
            .foregroundStyle(theme.textPrimary)
        } else {
            Text(l10n.string(.hadithMemorizeCaughtUp))
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 12) {
        HadithReviewRow(due: 3, action: {})
        HadithReviewRow(due: 0, action: {})
    }
    .padding()
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
