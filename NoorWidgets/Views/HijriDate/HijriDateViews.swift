//
//  HijriDateViews.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// The Home Screen families: the Hijri date large, the Gregorian one under it, and whatever falls
/// on the day.
///
/// One view for both sizes. The small and the medium differ only in how much of the event line
/// there is room for, which is a `lineLimit` rather than a layout — and a second file whose only
/// difference was that number would be a second file to keep in step.
struct HijriDateSystemView: View {

    let entry: HijriDateSnapshot

    @Environment(\.widgetFamily) private var family
    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(entry.style) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(l10n.hijri(entry.hijri))
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                // The Hijri date is why the widget is here, so it is the one thing allowed two
                // lines — a month name and a four-figure year do not always fit a small family
                // on one, and shrinking the headline to keep it there would make it smaller than
                // the Gregorian date underneath.
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(l10n.date(entry.date))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let event = entry.events.first {
                Spacer(minLength: AppSpacing.xs)

                EventLabel(event: event, style: entry.style, lineLimit: eventLineLimit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var eventLineLimit: Int {
        family == .systemSmall ? 2 : 1
    }
}

/// What falls on this day, with the caveat that belongs to it.
///
/// **The note is not fine print.** For Ramadan and the two Eids it is the difference between a
/// calculated date and an announced one, and showing it is what keeps the widget from implying an
/// authority the app does not have — the same rule `IslamicEventBadge` follows in the app. Where
/// there is no room for the note, the *event* is what goes: a bare "Eid al-Fitr" on a Home Screen
/// is the claim this is written to avoid.
private struct EventLabel: View {
    let event: IslamicEvent
    let style: NextPrayerSnapshot.Style
    let lineLimit: Int

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l10n.string(event.nameKey))
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.accent)

            if let noteKey = event.noteKey, lineLimit > 1 {
                Text(l10n.string(noteKey))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}
