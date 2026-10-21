//
//  MonthGridView.swift
//  ThawabForGod
//

import SwiftUI

/// One month as seven columns of days. A page of the pager.
struct MonthGridView: View {
    let key: HijriMonthKey
    let viewModel: HijriCalendarViewModel
    let rowHeight: CGFloat

    @Environment(LocalizationManager.self) private var l10n

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        if let grid = viewModel.grid(for: key) {
            let markers = viewModel.markers(in: grid)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(grid.cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        cell(day, marker: markers[day.gregorian] ?? DayMarker())
                    } else {
                        Color.clear.frame(minHeight: rowHeight)
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func cell(_ day: MonthGrid.Day, marker: DayMarker) -> some View {
        DayCell(
            day: day,
            marker: marker,
            gregorianNumber: viewModel.gregorianDayNumber(day.gregorian),
            isToday: viewModel.isToday(day.gregorian),
            isSelected: viewModel.isSelected(day.gregorian),
            showGregorian: viewModel.showGregorian,
            rowHeight: rowHeight,
            accessibilityLabel: label(for: day),
            select: { viewModel.select(day.gregorian) }
        )
    }

    /// `10 Muharram 1447, 4 July 2025` — and *Today* when it is, so a screen reader hears it
    /// without having to find the highlight.
    private func label(for day: MonthGrid.Day) -> String {
        let hijri = HijriDateText.string(
            for: viewModel.hijriDate(of: day.gregorian),
            localized: l10n.string,
            number: { l10n.string($0, grouped: $1) }
        )
        var parts = [l10n.string(.calendarDayAccessibility, hijri, l10n.dateString(day.gregorian))]
        if viewModel.isToday(day.gregorian) { parts.append(l10n.string(.calendarToday)) }
        parts += viewModel.occasions(on: day.gregorian).map { l10n.string($0.nameKey) }
        return parts.joined(separator: ", ")
    }
}
