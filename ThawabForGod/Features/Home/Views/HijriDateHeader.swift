//
//  HijriDateHeader.swift
//  ThawabForGod
//

import SwiftUI
import TipKit // `.popoverTip(_:)`; MEMBER_IMPORT_VISIBILITY means it is not re-exported

/// Today's Hijri date, and whatever the Islamic calendar marks on it.
///
/// Sits above the prayer times in every phase — including `.unavailable`, where the times
/// could not be computed but the date is still the date.
struct HijriDateHeader: View {
    let viewModel: HomeViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HijriDateLabel(date: viewModel.hijriDate)
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
        // The year is ungrouped: it names a year, it does not count 1,448 of anything.
        "\(l10n.string(date.day)) \(l10n.string(date.month.labelKey)) \(l10n.string(date.year, grouped: false))"
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
        .background(theme.accent.opacity(0.12), in: .rect(cornerRadius: 12))
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
    .padding(20)
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
