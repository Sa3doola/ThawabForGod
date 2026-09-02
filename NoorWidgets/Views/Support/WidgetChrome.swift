//
//  WidgetChrome.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Everything the three widget kinds do *around* their content.
///
/// Each kind differs only in which layout it picks for a family. The theme, the locale, the layout
/// direction, the deep link and the ground behind it are the same argument three times over — so
/// they are made once, here, and a fourth kind costs a `WidgetChrome` and a family switch.
///
/// It also owns the two states that are not a schedule. A `switch` over the content rather than a
/// chain of `if let`: `noLocation` and `notComputable` are answers, not failures, and each has
/// something specific to say. Falling through to a blank rectangle — or worse, to Makkah's times —
/// is exactly what this shape prevents.
struct WidgetChrome<Content: View>: View {

    let entry: NextPrayerSnapshot

    /// Where a tap lands. Every kind opens the day sheet today; the parameter is here so a kind
    /// that wants somewhere else does not have to unpick this view to say so.
    var link: DeepLink = .prayerTimes

    /// The layout for this family, given a day. Called only in the `.schedule` case — the other
    /// two states have no day to hand it.
    @ViewBuilder let content: (NextPrayerSnapshot.Day) -> Content

    @Environment(\.widgetFamily) private var family

    private var theme: Theme { Theme(accent: entry.style.accent) }
    private var l10n: WidgetLocalization { WidgetLocalization(entry.style) }

    var body: some View {
        body(for: entry.content)
            // On the ramp the palette is inverted, so every view inside goes on reading the same
            // tokens — see `Theme.onDayRamp`.
            .environment(\.theme, rampStop == nil ? theme : theme.onDayRamp)
            // The numbering system, as a locale, because `Text(timerInterval:)` is rendered by
            // the system and is the one string in this app whose digits it cannot format itself.
            .environment(\.locale, l10n.locale)
            .environment(
                \.layoutDirection,
                entry.style.language.isRightToLeft ? .rightToLeft : .leftToRight
            )
            .widgetURL(link.url)
            .containerBackground(for: .widget) {
                if let rampStop {
                    DayRampBackground(stop: rampStop)
                } else {
                    theme.background
                }
            }
    }

    @ViewBuilder
    private func body(for state: NextPrayerSnapshot.Content) -> some View {
        switch state {
        case .schedule(let day):
            content(day)

        case .noLocation:
            NoticeView(message: l10n.string(.widgetNoLocation), symbol: "location.slash")

        case .notComputable:
            NoticeView(
                message: l10n.string(.widgetTimesUnavailable),
                symbol: "sun.max.trianglebadge.exclamationmark"
            )
        }
    }

    /// The day's light behind this entry, or `nil` where the ramp must not be drawn.
    ///
    /// Two exclusions, and both are the point. **The Lock Screen accessories never get it**: the
    /// system renders those monochrome and vibrant, so a gradient there is redrawn as a flat
    /// smear and the lattice as noise. **`noLocation` and `notComputable` never get it** either —
    /// the ramp *is* a claim about what time it is, and a widget that does not know where it is
    /// has no business making one.
    ///
    /// Where it is drawn, it steps rather than glides: an entry exists per prayer transition, so
    /// there is nothing between two markers for an interpolation to move across. That is the
    /// honest widget reading of the same ramp the app's card blends through — one entry, one
    /// light, and the light changes exactly when the prayer does.
    private var rampStop: DayRampStop? {
        guard case .schedule(let day) = entry.content, isSystemFamily else { return nil }
        return DayRamp.stop(for: day.current ?? day.upcoming.prayer)
    }

    private var isSystemFamily: Bool {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: true
        default: false
        }
    }
}

/// The two states with nothing to count down to.
///
/// Both say what is wrong in a sentence rather than showing a dash, because the reader's next
/// move differs — one is "open Noor and set your location", the other is "the sun does not rise
/// or set here today" — and a widget that merely looked broken would get deleted instead of
/// fixed.
struct NoticeView: View {
    let message: String
    let symbol: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(theme.accent)

            Text(message)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
