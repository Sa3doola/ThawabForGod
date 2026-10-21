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

    var body: some View {
        let today = calendar.today
        let hijri = HijriDateText.string(
            for: calendar.hijriDate(of: today),
            localized: l10n.string,
            number: { l10n.string($0, grouped: $1) }
        )
        let moon = calendar.moon(on: today)
        let phase = l10n.string(moon.phase.labelKey)

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

                    if let line = occasionLine(today) {
                        Text(line)
                            .appFont(.footnote, weight: .medium)
                            .foregroundStyle(theme.textPrimary)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                VStack(spacing: 4) {
                    MoonView(
                        illuminatedFraction: moon.illuminatedFraction,
                        isWaxing: moon.isWaxing,
                        hemisphere: calendar.hemisphere,
                        accessibilityText: phase
                    )
                    .frame(width: 44, height: 44)
                    .padding(6)
                    .background { DayRampBackground(stop: DayRamp.stop(for: .isha)) }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(phase)
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(l10n.string(.homeCalendarHint))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.islamicCalendar")
    }

    /// An occasion that falls today, or failing that the next one and how far off it is.
    private func occasionLine(_ today: Date) -> String? {
        if let now = calendar.occasions(on: today).first(where: { !$0.isRecurring }) {
            return l10n.string(.homeCalendarTodayLine, l10n.string(now.nameKey))
        }
        guard let next = calendar.upcoming(limit: 1).first else { return nil }
        return l10n.string(
            .homeCalendarNextLine,
            l10n.string(next.occasion.nameKey),
            l10n.daysAwayString(calendar.daysAway(to: next))
        )
    }
}
