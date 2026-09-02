//
//  HomeHeader.swift
//  ThawabForGod
//

import SwiftUI
import TipKit // `.popoverTip(_:)`; MEMBER_IMPORT_VISIBILITY means it is not re-exported

/// Home's chrome: who is being greeted, what day it is, and anything the calendar marks on it.
///
/// **Not a section.** Everything below it is ordered and hideable by the user; this is the
/// screen's own frame and is neither. It sits outside the `LazyVStack`'s section loop for that
/// reason rather than as an accident of layout.
///
/// It shows both calendars side by side because the app has two and they disagree: the Hijri
/// date is what the content is organised around, and the Gregorian one is what the reader's phone
/// and diary say. Showing only the first makes the app hard to use; only the second makes it
/// hard to trust.
struct HomeHeader: View {
    let viewModel: HomeViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(viewModel.greeting.labelKey))
                .appFont(.title2, weight: .bold)
                .foregroundStyle(theme.textPrimary)

            DateLine(date: viewModel.currentDate, hijri: viewModel.hijriDate)
                .popoverTip(hijriDateTip)

            ForEach(viewModel.todaysEvents) { event in
                IslamicEventBadge(event: event)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Rebuilt each redraw so the copy follows a language change; identity is the tip's fixed
    /// `id`, so this never re-shows a dismissed tip.
    private var hijriDateTip: HomeHijriDateTip {
        HomeHijriDateTip(
            titleText: l10n.string(.tipHomeHijriTitle),
            messageText: l10n.string(.tipHomeHijriMessage)
        )
    }
}

/// Both calendars on one line.
private struct DateLine: View {
    let date: Date
    let hijri: HijriDate

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .appFont(.callout, weight: .medium)
            .foregroundStyle(theme.textSecondary)
            // One string rather than two `Text`s in a stack, for the reason `HijriDateLabel`
            // gives: a stack would fix the visual order of the two dates, where a single run
            // lets the bidi algorithm lay them out the way the reading direction requires.
            .accessibilityLabel(text)
    }

    private var text: String {
        "\(l10n.dateString(date)) · \(HijriDateLabel.text(for: hijri, l10n: l10n))"
    }
}

/// The date itself, assembled from localized parts rather than a formatter.
///
/// `DateFormatter` could produce this in one call, but only by following the locale for both
/// the month name *and* the digits — and this app treats those as separate choices, so an
/// Arabic reader who prefers Latin digits would get Arabic-Indic ones anyway. Composing the
/// three pieces keeps each on the setting that governs it.
struct HijriDateLabel: View {
    let date: HijriDate

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .appFont(.callout, weight: .medium)
            .foregroundStyle(theme.textSecondary)
            // One string, not three `Text`s in an `HStack`: a stack would fix the visual order
            // of day, month and year, whereas a single run lets the bidi algorithm lay them
            // out the way the reading direction requires.
            .accessibilityLabel(text)
    }

    private var text: String {
        Self.text(for: date, l10n: l10n)
    }

    /// Shared with `HomeHeader`'s date line, which shows this reading beside the Gregorian one.
    ///
    /// The assembly itself is `HijriDateText`, in `Shared/`, because the widget extension draws
    /// the same line and two spellings of one date is exactly the kind of drift that goes
    /// unnoticed until somebody puts the app and the Lock Screen side by side.
    static func text(for date: HijriDate, l10n: LocalizationManager) -> String {
        HijriDateText.string(
            for: date,
            localized: { l10n.string($0) },
            number: { l10n.string($0, grouped: $1) }
        )
    }
}

/// One marked day, with the caveat that belongs to it.
///
/// The note is not fine print to be hidden — for Ramadan and the two Eids it is the difference
/// between a calculated date and the announced one, and showing it is what keeps the app from
/// implying an authority it does not have.
struct IslamicEventBadge: View {
    let event: IslamicEvent

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.string(event.nameKey))
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(theme.accent)

            if let noteKey = event.noteKey {
                Text(l10n.string(noteKey))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        // Leading and trailing, never left and right — which is what mirrors the badge for
        // Arabic without a second layout.
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.12), in: .rect(cornerRadius: AppRadius.md))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(alignment: .leading, spacing: 20) {
        HijriDateLabel(date: HijriDate(day: 10, month: .muharram, year: 1447))

        IslamicEventBadge(
            event: IslamicEvent(
                id: "ashura",
                nameKey: .eventAshura,
                noteKey: nil,
                month: .muharram,
                day: 10
            )
        )

        IslamicEventBadge(
            event: IslamicEvent(
                id: "eid_al_fitr",
                nameKey: .eventEidAlFitr,
                noteKey: .eventNoteMoonSighting,
                month: .shawwal,
                day: 1
            )
        )
    }
    .padding(AppSpacing.xl)
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
