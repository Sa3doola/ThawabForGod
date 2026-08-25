//
//  TodayTimesSection.swift
//  ThawabForGod
//

import SwiftUI

/// The day's six markers, as a card of their own.
///
/// **Its own section rather than a second surface inside the hero.** The two were built as one
/// card — a ramp with a strip stapled underneath — and they are not one thing: the hero is the
/// *next* prayer and the strip is the *whole day*, which is why they never shared a ground. Once
/// they are separate to the eye they should be separate to the arrangement too, or the reader who
/// wants the times without the countdown, or the countdown without the times, has no way to say
/// so. Splitting them gives the strip a row in the customization screen like every other card.
///
/// It stays tappable, and opens the same day sheet the hero does: tapping a summary to see the
/// thing it summarises is what a reader expects of either.
struct TodayTimesSection: View {
    let state: NextPrayerState

    /// Opens the day sheet.
    let open: () -> Void

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Button(action: open) {
            DayPrayerRow(state: state)
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity)
                .appCard()
        }
        .buttonStyle(.plain)
        .appHover()
        .accessibilityHint(l10n.string(.prayerTimesSheetHint))
    }
}
