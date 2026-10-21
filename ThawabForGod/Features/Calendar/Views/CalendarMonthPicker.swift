//
//  CalendarMonthPicker.swift
//  ThawabForGod
//

import SwiftUI

/// Jumps to any month and year the calendar covers.
struct CalendarMonthPicker: View {
    let viewModel: HijriCalendarViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        NavigationStack {
            Form {
                Picker(l10n.string(.calendarYearLabel), selection: year) {
                    ForEach(Array(viewModel.supportedYears), id: \.self) { year in
                        Text(l10n.string(year, grouped: false)).tag(year)
                    }
                }

                Picker(l10n.string(.calendarMonthLabel), selection: month) {
                    ForEach(HijriMonth.allCases) { month in
                        Text(l10n.string(month.labelKey)).tag(month)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(l10n.string(.calendarPickMonth))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.calendarDone)) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 320, minHeight: 220)
        #endif
        .presentationDetents([.medium])
    }

    private var year: Binding<Int> {
        Binding(
            get: { viewModel.visibleMonth.year },
            set: { viewModel.show(HijriMonthKey(year: $0, month: viewModel.visibleMonth.month)) }
        )
    }

    private var month: Binding<HijriMonth> {
        Binding(
            get: { viewModel.visibleMonth.month },
            set: { viewModel.show(HijriMonthKey(year: viewModel.visibleMonth.year, month: $0)) }
        )
    }
}
