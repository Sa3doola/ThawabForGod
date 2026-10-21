//
//  IslamicCalendarSection.swift
//  ThawabForGod
//

import SwiftUI

/// Today in both calendars, tonight's moon, and what is coming up — one card that opens the
/// calendar.
///
/// It reads the calendar's own view model rather than recomputing, so Home and the calendar
/// screen cannot disagree about the date, the Hijri offset or which occasion is next. `day` is
/// Home's own notion of now: passing it in is what makes the card redraw when Home does at
/// midnight, instead of showing yesterday until something else invalidates it.
struct IslamicCalendarSection: View {
    let calendar: HijriCalendarViewModel
    let day: Date
    let open: (AppRoute) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let today = calendar.today
        let hijri = HijriDateText.string(
            for: calendar.hijriDate(of: today),
            localized: l10n.string,
            number: { l10n.string($0, grouped: $1) }
        )
        let moon = calendar.moon(on: today)
        let phase = l10n.string(moon.phase.labelKey)
        let percent = l10n.string(.moonPercentValue, l10n.string(Int((moon.illuminatedFraction * 100).rounded())))

        Button {
            open(.hijriCalendar(selecting: nil))
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.string(.homeSectionIslamicCalendar))
                        .appFont(.footnote)
                        .foregroundStyle(theme.textSecondary)

                    Text(hijri)
                        .appFont(.title3, weight: .semibold)
                        .foregroundStyle(theme.accent)

                    Text(l10n.dateString(today))
                        .appFont(.subheadline)
                        .foregroundStyle(theme.textSecondary)

                    Text(l10n.string(.homeCalendarMoonLine, phase, percent))
                        .appFont(.footnote)
                        .foregroundStyle(theme.textSecondary)

                    if let line = occasionLine(today) {
                        Text(line)
                            .appFont(.footnote, weight: .medium)
                            .foregroundStyle(theme.textPrimary)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                // At accessibility sizes the words need the width; the moon line says it all.
                if !dynamicTypeSize.isAccessibilitySize {
                MoonView(
                    illuminatedFraction: moon.illuminatedFraction,
                    isWaxing: moon.isWaxing,
                    hemisphere: calendar.hemisphere,
                    accessibilityText: l10n.string(.moonAccessibilityLabel, phase, percent)
                )
                .frame(width: 52, height: 52)
                .padding(6)
                .background { DayRampBackground(stop: DayRamp.stop(for: .isha)) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .appCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(l10n.string(.homeCalendarHint))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.islamicCalendar")
    }

    /// Today's occasion always; the next one only when it is close enough to be news.
    private func occasionLine(_ today: Date) -> String? {
        switch calendar.cardOccasion(lookAheadDays: Self.lookAheadDays) {
        case .today(let occasion):
            l10n.string(.homeCalendarTodayLine, l10n.string(occasion.nameKey))
        case .upcoming(let occasion, let days):
            l10n.string(.homeCalendarNextLine, l10n.string(occasion.nameKey), l10n.daysAwayString(days))
        case nil:
            nil
        }
    }

    /// How far ahead the card is willing to look. Further than a week it stops being news and
    /// becomes clutter; the calendar screen has the full list.
    static let lookAheadDays = 7
}
