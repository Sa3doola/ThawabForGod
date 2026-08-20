//
//  NextPrayerCard.swift
//  ThawabForGod
//

import SwiftUI

/// Home's headline, and the one section that can never be hidden: which prayer is next, where,
/// how long is left, and the whole day underneath.
///
/// One card rather than a card and a list. The day used to sit below in its own panel, which
/// made the screen two answers to the same question — the row along the bottom of this card is
/// that list, folded in, with the marker being counted down to picked out of it.
struct NextPrayerCard: View {
    let viewModel: HomeViewModel
    let state: NextPrayerState

    /// Opens the day sheet. The whole card is the target, not a chevron in the corner — the card
    /// *is* a summary of the day, and tapping a summary to see the thing it summarises is what a
    /// reader expects of it.
    let open: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: open) {
            card
        }
        .buttonStyle(.plain)
        .accessibilityHint(l10n.string(.prayerTimesSheetHint))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            NextPrayerHeadline(state: state, placeName: viewModel.placeName)
            NextPrayerCountdown(viewModel: viewModel, state: state)

            Divider().overlay(theme.separator)

            DayPrayerRow(state: state)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(theme.separator)
        }
    }
}

/// The name, the time, and where the times are for.
private struct NextPrayerHeadline: View {
    let state: NextPrayerState
    let placeName: String?

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.string(.nextPrayerLabel))
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)

            // The name and the time share a line until they cannot. At an accessibility size
            // "المغرب" and "٥:٤٢ م" together are wider than a phone, and the pair on one line
            // truncates the *prayer's name* — which is the one word on this screen that has to
            // be readable. Stacking is what a reader at that size is already expecting.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    name
                    time
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    name
                    Spacer(minLength: 12)
                    time
                }
            }

            if state.upcoming.isTomorrow {
                Text(l10n.string(.tomorrowLabel))
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }

            // Absent rather than empty when there is no name: the coordinates work offline, the
            // name does not, and a placeholder would advertise a failure nobody can act on.
            if let placeName {
                Label(placeName, systemImage: "mappin.and.ellipse")
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var name: some View {
        Text(l10n.string(state.upcoming.prayer.labelKey))
            .appFont(.title, weight: .bold)
            .foregroundStyle(theme.textPrimary)
    }

    private var time: some View {
        Text(l10n.timeString(state.upcoming.date))
            .appFont(.title3, weight: .semibold)
            .foregroundStyle(theme.accent)
            .monospacedDigit()
    }
}

/// The ticking half, split out on purpose.
///
/// Observation tracks reads per property, and this is the only view that reads `countdown` — so
/// the once-a-second change invalidates this block alone, not the headline and not the six
/// entries along the bottom.
private struct NextPrayerCountdown: View {
    let viewModel: HomeViewModel
    let state: NextPrayerState

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(.timeRemainingLabel))
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(theme.textSecondary)

            Text(l10n.countdownString(viewModel.countdown))
                .appFont(.largeTitle, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                // Digits vary in width as they tick; a monospaced set stops the label jittering.
                .monospacedDigit()
                // Read as a sentence rather than as six digits and two colons. VoiceOver would
                // otherwise say "two colon five seven colon zero three" every second.
                .accessibilityLabel(spokenRemaining)
                .accessibilityAddTraits(.updatesFrequently)

            // How far through the gap between the last prayer and the next we are. Hidden from
            // assistive technology because the label above already says it, in words.
            ProgressView(value: state.progress(remaining: viewModel.countdown))
                .progressViewStyle(.linear)
                .tint(theme.accent)
                .accessibilityHidden(true)
        }
    }

    /// "2 hours 57 minutes until Asr".
    ///
    /// `Duration`'s own unit style rather than the app's digit formatter, and it is the one place
    /// that is right: this string is *spoken*, never drawn, so what matters is that the units are
    /// worded and inflected correctly in the user's language — which is a job for the locale, not
    /// for a choice about which glyphs to print.
    private var spokenRemaining: String {
        let remaining = Duration.seconds(max(0, viewModel.countdown))
            .formatted(
                .units(allowed: [.hours, .minutes], width: .wide, maximumUnitCount: 2)
                    .locale(l10n.locale)
            )

        return l10n.string(
            .countdownAccessibility,
            remaining,
            l10n.string(state.upcoming.prayer.labelKey)
        )
    }
}
