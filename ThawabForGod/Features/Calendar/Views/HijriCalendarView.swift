//
//  HijriCalendarView.swift
//  ThawabForGod
//

import SwiftUI

/// The Islamic calendar: today's Hijri date over its Gregorian one, a month at a time, with the
/// selected day's moon and occasions underneath.
///
/// A push on Home's stack rather than a tab — it is a visit that ends by going back.
struct HijriCalendarView: View {
    let viewModel: HijriCalendarViewModel

    @Environment(\.theme) private var theme
    @Environment(LocalizationManager.self) private var l10n
    @State private var isPickingMonth = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                monthBar
                weekdayRow
                MonthPager(viewModel: viewModel)
                SelectedDayPanel(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.calendarTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .sheet(isPresented: $isPickingMonth) {
            CalendarMonthPicker(viewModel: viewModel)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                HijriDateText.string(
                    for: viewModel.hijriDate(of: viewModel.selectedDay),
                    localized: l10n.string,
                    number: { l10n.string($0, grouped: $1) }
                )
            )
            .appFont(.title2, weight: .semibold)
            .foregroundStyle(theme.accent)

            Text(l10n.dateString(viewModel.selectedDay))
                .appFont(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var monthBar: some View {
        HStack {
            Button {
                isPickingMonth = true
            } label: {
                let key = viewModel.visibleMonth
                Text("\(l10n.string(key.month.labelKey)) \(l10n.string(key.year, grouped: false))")
                    .appFont(.headline)
                    .foregroundStyle(theme.textPrimary)
            }
            .buttonStyle(.plain)

            Spacer()

            // `chevron.backward` / `.forward` mirror with the layout on their own, so "previous"
            // points the way the pager moves in both languages.
            Button { viewModel.step(by: -1) } label: {
                Image(systemName: "chevron.backward")
            }
            .accessibilityLabel(l10n.string(.calendarPreviousMonth))

            Button { viewModel.step(by: 1) } label: {
                Image(systemName: "chevron.forward")
            }
            .accessibilityLabel(l10n.string(.calendarNextMonth))
        }
        .foregroundStyle(theme.accent)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.columnWeekdays, id: \.self) { weekday in
                Text(l10n.weekdayString(viewModel.referenceDate(forWeekday: weekday)))
                    .appFont(.caption, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .accessibilityHidden(true)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(l10n.string(.calendarToday)) { viewModel.goToToday() }
        }

        ToolbarItem(placement: .primaryAction) {
            @Bindable var viewModel = viewModel
            Menu {
                Toggle(l10n.string(.calendarShowGregorian), isOn: $viewModel.showGregorian)

                Picker(l10n.string(.calendarWeekStartsOn), selection: $viewModel.weekStart) {
                    ForEach(WeekStart.allCases, id: \.self) { start in
                        Text(l10n.string(start.labelKey)).tag(start)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

extension WeekStart {
    var labelKey: L10nKey {
        switch self {
        case .locale: .calendarWeekStartLocale
        case .saturday: .calendarWeekStartSaturday
        case .sunday: .calendarWeekStartSunday
        case .monday: .calendarWeekStartMonday
        }
    }
}
