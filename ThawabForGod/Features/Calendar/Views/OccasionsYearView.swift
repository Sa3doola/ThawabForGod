//
//  OccasionsYearView.swift
//  ThawabForGod
//

import SwiftUI

/// Every once-a-year occasion of a Hijri year, grouped by the month it begins in, with a stepper
/// for the year.
struct OccasionsYearView: View {
    let viewModel: HijriCalendarViewModel

    @Environment(\.theme) private var theme
    @Environment(LocalizationManager.self) private var l10n
    @State private var year: Int
    @State private var sheet: OccasionSheetItem?

    init(viewModel: HijriCalendarViewModel) {
        self.viewModel = viewModel
        _year = State(initialValue: viewModel.visibleMonth.year)
    }

    var body: some View {
        let occurrences = viewModel.occurrences(inYear: year)

        List {
            Section {
                yearStepper
            }

            ForEach(HijriMonth.allCases) { month in
                let inMonth = occurrences.filter { $0.first.hijri.month == month }
                if !inMonth.isEmpty {
                    Section(l10n.string(month.labelKey)) {
                        ForEach(inMonth) { occurrence in
                            OccasionRow(
                                occurrence: occurrence,
                                daysAway: viewModel.daysAway(to: occurrence),
                                open: { sheet = item(for: occurrence) }
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(l10n.string(.occasionsYearTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $sheet) { OccasionDetailSheet(item: $0) }
    }

    private var yearStepper: some View {
        HStack {
            Button { year -= 1 } label: { Image(systemName: "chevron.backward") }
                .disabled(year <= viewModel.supportedYears.lowerBound)
                .accessibilityLabel(l10n.string(.occasionsPreviousYear))

            Spacer()

            Text(l10n.string(year, grouped: false))
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Button { year += 1 } label: { Image(systemName: "chevron.forward") }
                .disabled(year >= viewModel.supportedYears.upperBound)
                .accessibilityLabel(l10n.string(.occasionsNextYear))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(theme.accent)
    }

    private func item(for occurrence: OccasionOccurrence) -> OccasionSheetItem {
        OccasionSheetItem(
            occasion: occurrence.occasion,
            dateLine: OccasionDateText.hijri(
                first: occurrence.first.hijri,
                last: occurrence.last.hijri,
                localized: l10n.string,
                number: { l10n.string($0, grouped: $1) }
            )
        )
    }
}
