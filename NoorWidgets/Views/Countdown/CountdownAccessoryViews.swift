//
//  CountdownAccessoryViews.swift
//  NoorWidgets
//

#if os(iOS)
import SwiftUI
import WidgetKit

/// The Lock Screen slots that answer *how long*.
///
/// Both are a `ProgressView(timerInterval:)` — a ring in the circle, a bar in the rectangle — over
/// the same window, `PrayerWindow.range(for:)`. The timer form is what makes either possible at
/// all: every entry in this timeline is built *at* a prayer transition, so a computed fraction
/// would be zero in every entry that ever rendered and the progress would sit permanently empty.
/// The system drains the timer form on its own between redraws, which costs the extension nothing.
///
/// Like every accessory family, neither reads `theme`: the system renders these in one tint.

/// The circle: a ring that empties as the prayer approaches, with the countdown inside it.
struct CountdownAccessoryCircularView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        ProgressView(timerInterval: PrayerWindow.range(for: day), countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 0) {
                CountdownText(to: day.upcoming.date)
                    .font(.caption2)

                Text(l10n.string(day.upcoming.prayer.labelKey))
                    .font(.caption2)
                    .textCase(.uppercase)
            }
            // The inside of an accessory circle is barely thirty points across, and an Arabic
            // name is a wider string than "Asr". Both lines shrink rather than truncate: a
            // clipped countdown is unreadable, and a clipped name is the wrong prayer.
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .progressViewStyle(.circular)
        .background { AccessoryWidgetBackground() }
        // The two labels read as "1:24, Asr" one after the other, which is not a sentence.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(day.upcoming.prayer.labelKey))
        .accessibilityValue(l10n.countdown(day.upcoming.date.timeIntervalSinceNow))
    }
}

/// The rectangle: the prayer and the countdown on one line, and the same window as a bar beneath.
///
/// The bar is the reason to choose this over the circle rather than a decoration on it — a
/// rectangle is wide enough for the elapsed fraction to be read as a *quantity*, which thirty
/// points of ring is not.
struct CountdownAccessoryRectangularView: View {
    let day: NextPrayerSnapshot.Day
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: AppSpacing.xs) {
                Label {
                    Text(l10n.string(day.upcoming.prayer.labelKey))
                } icon: {
                    Image(systemName: day.upcoming.prayer.symbol)
                }
                .font(.caption)

                Spacer(minLength: 2)

                CountdownText(to: day.upcoming.date)
                    .font(.headline)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // `.linear` explicitly: the default style for a `timerInterval` progress view is
            // circular in some contexts, and a ring here would be the other widget.
            ProgressView(timerInterval: PrayerWindow.range(for: day), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(day.upcoming.prayer.labelKey))
        .accessibilityValue(l10n.countdown(day.upcoming.date.timeIntervalSinceNow))
    }
}
#endif
