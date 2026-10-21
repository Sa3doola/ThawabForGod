//
//  DayCell.swift
//  ThawabForGod
//

import SwiftUI

/// One day in the month grid: the Hijri number, optionally the Gregorian one under it, and a dot
/// when the day carries an occasion.
///
/// *Today* is a filled rounded highlight and the *selected* day an outline — two marks, because a
/// day can be either, both or neither, as in the system Calendar.
struct DayCell: View {
    let day: MonthGrid.Day
    let marker: DayMarker
    let gregorianNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let showGregorian: Bool
    let accessibilityLabel: String
    let select: () -> Void

    @Environment(\.theme) private var theme
    @Environment(LocalizationManager.self) private var l10n

    private let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Button(action: select) {
            VStack(spacing: 2) {
                Text(l10n.string(day.number, grouped: false))
                    .appFont(.body, weight: isToday ? .semibold : .regular)
                    .foregroundStyle(isToday ? theme.background : theme.textPrimary)

                if showGregorian {
                    Text(l10n.string(gregorianNumber, grouped: false))
                        .appFont(.caption)
                        .foregroundStyle(isToday ? theme.background.opacity(0.85) : theme.textSecondary)
                }

                dot
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background { if isToday { shape.fill(theme.accent) } }
            .overlay { if isSelected { shape.strokeBorder(theme.accent, lineWidth: 2) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Always laid out, so a day with no occasion is not shorter than one with.
    private var dot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 5, height: 5)
    }

    /// The loud dot for a one-off occasion, the quiet one for a recurring fast, none otherwise.
    private var dotColor: Color {
        let base = isToday ? theme.background : theme.accent
        if marker.hasOccasion { return base }
        if marker.hasRecurring { return base.opacity(0.35) }
        return .clear
    }
}
