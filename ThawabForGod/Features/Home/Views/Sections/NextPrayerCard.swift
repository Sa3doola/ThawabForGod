//
//  NextPrayerCard.swift
//  ThawabForGod
//

import SwiftUI

/// Home's headline, and the one section that can never be hidden: which prayer is next, how long
/// is left, and the whole day underneath.
///
/// **The card is the time of day.** Its ground is `DayRamp` — the light between the marker just
/// passed and the one being counted down to — so the screen is a different colour at Fajr than at
/// Isha without a word changing. That is the organising idea of the whole design, and this is the
/// first of the three places it is allowed to appear.
///
/// **The day's six markers are inside it, not in a card of their own.** They were split out for a
/// while, on the argument that the hero is the *next* prayer and the strip is the *whole day* — two
/// questions, so two surfaces. The screen said otherwise: a countdown and the strip it belongs to,
/// stacked as separate cards, are one thought with a rule drawn through it, and the reader's eye
/// crosses a card boundary to answer "and then?". The widget never made that split — see
/// `PrayerScheduleMediumView`, which is this same layout in 360 points — and the app now matches
/// it. One prayer-times surface, one tap, one ground.
///
/// The strip is a sibling in the stack rather than something the ramp is decorated with, and it
/// takes only `state`: everything that ticks is in `NextPrayerCountdown` and the rail, so the six
/// markers are rebuilt when a *prayer* changes rather than once a second.
struct NextPrayerCard: View {
    let viewModel: HomeViewModel
    let state: NextPrayerState

    /// Opens the day sheet.
    let open: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: open) {
            hero
        }
        .buttonStyle(.plain)
        .accessibilityHint(l10n.string(.prayerTimesSheetHint))
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                NextPrayerHeadline(state: state, placeName: viewModel.placeName)
                NextPrayerCountdown(viewModel: viewModel, state: state)
            }
            // The words keep the card's own margin; the strip below does not, and that is the
            // whole reason the padding is per-block rather than on the card. Six columns inside
            // a 24-point inset on each side is a third of a 4.7-inch phone spent on white space,
            // and at that width "4:52 AM" stops shrinking and truncates instead.
            .padding(.horizontal, AppSpacing.xl)

            DayPrayerStrip(state: state)
        }
        .padding(.top, AppSpacing.xl)
        // Less than the top, because the strip brings its own: `DayPrayerEntry` pads itself
        // vertically, so the card's full margin here would read as a band of nothing above the
        // rail.
        .padding(.bottom, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { DayRampSurface(viewModel: viewModel, state: state) }
        // The rail is the progress bar, drawn as the card's own bottom edge rather than as a
        // control inside it — a `ProgressView` on this ground would be a second, differently
        // shaped thing saying what the countdown above it already says.
        .overlay(alignment: .bottom) { NextPrayerRail(viewModel: viewModel, state: state) }
        .clipShape(.rect(cornerRadius: AppRadius.lg))
        .appElevation(.card)
        // Everything inside the hero goes on reading `theme.textPrimary` and friends; what
        // changes is which palette those names resolve to. See `Theme.onDayRamp`.
        .environment(\.theme, theme.onDayRamp)
    }
}

// MARK: - The day

/// The six markers, with the rule that separates them from the countdown above.
///
/// **A view of its own rather than a block inside `hero`, because of where the palette changes.**
/// `NextPrayerCard` swaps the theme for `Theme.onDayRamp` on the hero, which reaches the views
/// *inside* it — the card's own `theme` property is still the app's. A divider drawn from that
/// one would come out in the app's separator grey on a ground the whole design says is dark, so
/// the rule is drawn by something that reads the environment for itself.
private struct DayPrayerStrip: View {
    let state: NextPrayerState

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Divider()
                .overlay(theme.separator)
                // Inset from the card's edge rather than bleeding to it: a rule that runs the
                // full width would cut the card in two, which is the reading this merge exists
                // to undo.
                .padding(.horizontal, AppSpacing.lg)

            DayPrayerRow(state: state)
                .padding(.horizontal, AppSpacing.sm)
        }
    }
}

// MARK: - The ground

/// The ramp, on its own so the day's light can move without the words above it being rebuilt.
///
/// This view reads `countdown`, so Observation invalidates it once a second — but its body only
/// builds a value, and `DayRampStop` is `Equatable`, so SwiftUI re-renders the gradient and the
/// lattice underneath only when that value actually changes. The quantisation is what makes that
/// bite: rounding the fraction to sixtieths turns one repaint a second into about one a minute,
/// which is far finer than an eye can follow a gradient shifting over a three-hour window.
private struct DayRampSurface: View {
    let viewModel: HomeViewModel
    let state: NextPrayerState

    var body: some View {
        DayRampBackground(stop: stop)
    }

    private var stop: DayRampStop {
        // No near end — the hours before the day's Fajr, where anchoring the blend would need a
        // second day's times. The light is simply the one being counted down to.
        guard let previous = state.previous else {
            return DayRamp.stop(for: state.upcoming.prayer)
        }

        let elapsed = state.progress(remaining: viewModel.countdown)
        return DayRamp.stop(
            from: previous.prayer,
            to: state.upcoming.prayer,
            elapsed: (elapsed * 60).rounded(.down) / 60
        )
    }
}

/// How full the window is, as the card's bottom edge.
private struct NextPrayerRail: View {
    let viewModel: HomeViewModel
    let state: NextPrayerState

    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.separator)

                Rectangle()
                    .fill(theme.accent.opacity(0.92))
                    .frame(width: proxy.size.width * state.progress(remaining: viewModel.countdown))
            }
        }
        .frame(height: 3)
        // The countdown label above says this in words, and says it better.
        .accessibilityHidden(true)
    }
}

// MARK: - The words on the ramp

/// The name, the time, and where the times are for.
///
/// It reads `theme.textPrimary` like everything else in the app; the hero has already swapped the
/// palette for `Theme.onDayRamp`, so those names resolve to the fixed on-ramp ink here.
private struct NextPrayerHeadline: View {
    let state: NextPrayerState
    let placeName: String?

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(l10n.string(.nextPrayerLabel))
                .appFont(.caption, weight: .bold)
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(theme.textSecondary)

            // The name and the time share a line until they cannot. At an accessibility size
            // "المغرب" and "٥:٤٢ م" together are wider than a phone, and the pair on one line
            // truncates the *prayer's name* — which is the one word on this screen that has to
            // be readable. Stacking is what a reader at that size is already expecting.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    name
                    time
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    name
                    Spacer(minLength: AppSpacing.md)
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
                Label(placeName, systemImage: "location.fill")
                    .appFont(.footnote, weight: .medium)
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
            .foregroundStyle(theme.textSecondary)
            .monospacedDigit()
    }
}

/// The ticking half, split out on purpose.
///
/// Observation tracks reads per property, and this is one of only three views that read
/// `countdown` — so the once-a-second change invalidates this block, the rail and the ramp's
/// value, not the headline and not the six entries below.
private struct NextPrayerCountdown: View {
    let viewModel: HomeViewModel
    let state: NextPrayerState

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(l10n.countdownString(viewModel.countdown))
                .appFont(.largeTitle, weight: .bold)
                .foregroundStyle(theme.textPrimary)
                // Digits vary in width as they tick; a monospaced set stops the label jittering.
                .monospacedDigit()
                // Read as a sentence rather than as six digits and two colons. VoiceOver would
                // otherwise say "two colon five seven colon zero three" every second.
                .accessibilityLabel(spokenRemaining)
                .accessibilityAddTraits(.updatesFrequently)

            Text(l10n.string(.timeRemainingLabel))
                .appFont(.footnote, weight: .medium)
                .foregroundStyle(theme.textSecondary)
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

