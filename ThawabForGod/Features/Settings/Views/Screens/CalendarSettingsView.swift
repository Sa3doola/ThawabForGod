//
//  CalendarSettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// The Islamic calendar's preferences.
///
/// Like every screen here it owns nothing: the rows write through the calendar's own view model,
/// which is what the calendar screen, Home's card and the widget read, so a change made here is on
/// the screen behind it at once.
struct CalendarSettingsView: View {
    @Bindable var viewModel: HijriCalendarViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Form {
            Section {
                Toggle(l10n.string(.calendarShowGregorian), isOn: $viewModel.showGregorian)

                Picker(l10n.string(.calendarWeekStartsOn), selection: $viewModel.weekStart) {
                    ForEach(WeekStart.allCases, id: \.self) { start in
                        Text(l10n.string(start.labelKey)).tag(start)
                    }
                }
            }

            Section {
                Toggle(l10n.string(.calendarHideRecurringDots), isOn: $viewModel.hideRecurringDots)
            } footer: {
                Text(l10n.string(.calendarHideRecurringFooter))
            }

            Section {
                Picker(l10n.string(.calendarOffsetTitle), selection: offset) {
                    ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
                        Text(l10n.offsetLabel(value)).tag(value)
                    }
                }
            } footer: {
                Text(l10n.string(.calendarOffsetFooter))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.calendarTitle))
    }

    private var offset: Binding<Int> {
        Binding(get: { viewModel.dayOffset }, set: { viewModel.setDayOffset($0) })
    }
}

extension LocalizationManager {

    /// `No adjustment`, `Advance 1 day`, `Delay 2 days` — what an offset does to the date.
    /// A positive offset moves the date *forward*, which is what "advance" means here.
    func offsetLabel(_ offset: Int) -> String {
        switch offset {
        case 2...: string(.calendarOffsetAdvance2)
        case 1: string(.calendarOffsetAdvance1)
        case -1: string(.calendarOffsetDelay1)
        case ...(-2): string(.calendarOffsetDelay2)
        default: string(.calendarOffsetNone)
        }
    }
}
