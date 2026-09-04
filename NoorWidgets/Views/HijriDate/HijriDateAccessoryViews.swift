//
//  HijriDateAccessoryViews.swift
//  NoorWidgets
//

#if os(iOS)
import SwiftUI
import WidgetKit

/// The Lock Screen slots for the date.
///
/// None reads `theme`: the system draws every accessory family in a single tint, so an accent
/// chosen against the app's background would simply be ignored.
///
/// What separates them is how much of a date each can hold. The inline is one truncated line and
/// gets both calendars on it; the rectangle has two lines and can afford the full Hijri date over
/// the Gregorian one; the circle has room for a numeral and a word.

/// The line above the clock — `10 Muharram 1447 · 2 Sep`.
///
/// Both calendars, which is the point of the slot: the Lock Screen's own date line is Gregorian,
/// so a widget repeating only that would be a row saying nothing new. The Gregorian half is the
/// abbreviated, yearless form — the year is directly above it in the system's own line.
///
/// One `Text` rather than pieces in a stack, because a stack would fix the visual order of the two
/// dates where a single run lets the bidi algorithm lay them out the way the reading direction
/// requires. That is the same call `HomeHeader`'s date line makes.
struct HijriDateAccessoryInlineView: View {
    let entry: HijriDateSnapshot

    private var l10n: WidgetLocalization { WidgetLocalization(entry.style) }

    var body: some View {
        Text(l10n.hijri(entry.hijri))
    }
}

/// The rectangle: the Hijri date on its own line, the Gregorian one under it, and an event on a
/// third if the day has one.
///
/// Two lines rather than the inline's one is exactly the room the year needs, so nothing here is
/// abbreviated away.
struct HijriDateAccessoryRectangularView: View {
    let entry: HijriDateSnapshot

    private var l10n: WidgetLocalization { WidgetLocalization(entry.style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(l10n.hijri(entry.hijri))
                .font(.headline)

            Text(l10n.date(entry.date))
                .font(.caption)

            if let event = entry.events.first {
                Text(l10n.string(event.nameKey))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The circle: the Hijri day as a numeral, its month under it.
///
/// No year and no Gregorian date — thirty points will not hold them, and a circle that tried
/// would be four lines of illegible text. The numeral is what the slot is for: a reader glancing
/// at a Lock Screen wants to know it is the tenth, and the month is what tells them of what.
struct HijriDateAccessoryCircularView: View {
    let entry: HijriDateSnapshot

    private var l10n: WidgetLocalization { WidgetLocalization(entry.style) }

    var body: some View {
        VStack(spacing: 0) {
            Text(l10n.number(entry.hijri.day))
                .font(.title2)

            Text(l10n.string(entry.hijri.month.labelKey))
                .font(.caption2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(2)
        // "10, Muharram" one after the other is not a sentence, and the whole date is what a
        // reader asked for when they put a date on their Lock Screen.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.hijri(entry.hijri))
    }
}
#endif
