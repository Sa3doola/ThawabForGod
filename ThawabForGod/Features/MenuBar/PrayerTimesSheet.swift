//
//  PrayerTimesSheet.swift
//  ThawabForGod
//

import SwiftUI

/// The whole day, for any day: a date to step through, the six markers with what was prayed
/// against them, and where the night divides.
///
/// A sheet rather than a push, because it is a *look* rather than a place — the user comes to
/// check a time and goes straight back to what they were doing.
///
/// **It opens full**, and the panel sizes itself. Both of those are the sheet's own business
/// rather than the presenting view's, which is why the modifiers are down here next to the
/// content they measure — the same place `ReaderSettingsSheet` keeps its own.
///
/// The two platforms need opposite things and neither one's answer is a no-op on the other:
///
/// - **iOS** gets detents, opening at `.large` because the day is six markers, a night section
///   and a tracker header — more than half a phone screen holds. `.medium` stays *offered*, so
///   the reader can still drag it down to glance at the times over whatever was behind it, but
///   it is no longer where the sheet starts.
/// - **macOS** gets an explicit frame, because it has to. A Mac sheet is sized by its content's
///   ideal size, and a `List` has no ideal height to report — so without this the panel came up
///   as a title bar and a Done button with nothing between them, which is exactly what it did.
///   `.presentationDetents` does not fill that gap: it compiles on macOS and does nothing.
struct PrayerTimesSheet: View {
    let viewModel: PrayerTimesSheetViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Where the sheet opens, and where the reader has since dragged it to. Bound rather than
    /// fixed, because `.presentationDetents([.large])` alone would take the glance away instead
    /// of just starting past it.
    @State private var detent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeekStrip(viewModel: viewModel)
                }

                content
            }
            .navigationTitle(l10n.string(.prayerTimesSheetTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.string(.doneAction)) { dismiss() }
                }
            }
            // Keyed on the day, so stepping the date recomputes — and cancels the outgoing
            // computation if the user steps twice quickly.
            .task(id: viewModel.day) { await viewModel.load() }
            .alert(
                item: Bindable(viewModel).explaining,
                title: { l10n.string($0.labelKey) },
                message: { l10n.string($0.explanationKey) }
            )
        }
        #if os(macOS)
        // The ideal is what a comfortable window gets; the minimum has to stay under the
        // window's own minimum content height (480, set in `ThawabForGodApp`) or a sheet on a
        // shrunken window would be clipped rather than scrolled.
        .frame(minWidth: 420, idealWidth: 520, minHeight: 400, idealHeight: 640)
        #else
        .presentationDetents([.medium, .large], selection: $detent)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)

        case .ready(let schedule):
            Section {
                ForEach(schedule.times) { time in
                    PrayerDetailRow(viewModel: viewModel, time: time)
                }
            } header: {
                TrackerHeader(record: viewModel.record, streak: viewModel.streak)
            }

            if let night = schedule.night {
                NightSection(night: night)
            }

        case .unavailable:
            Text(l10n.string(.prayerTimesUnavailable))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

/// ‹ S M T W T F S › — a week of tiles, with the Hijri date and a way back to today under it.
///
/// **A strip rather than the single-date stepper this replaced.** A stepper answers "what about
/// tomorrow?" in one tap and "what about Friday?" in an unknown number of them, and this screen is
/// where the reader goes *looking* — most often at a day this week. Seven tiles make that one tap
/// and cost no more height than the one date did, because the date it used to spell out is now the
/// Hijri line underneath.
///
/// The chevrons page a whole week; see the view model.
private struct WeekStrip: View {
    let viewModel: PrayerTimesSheetViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                // `chevron.backward` and `chevron.forward`, never left and right: the semantic
                // direction flips for Arabic and the literal one does not, so "the week before"
                // stays on the side the reader expects it.
                pageButton(symbol: "chevron.backward", action: viewModel.showPreviousWeek)
                    .accessibilityLabel(l10n.string(.previousWeekAction))

                // Equal columns rather than a stack of tiles: seven tiles whose ideal widths
                // differ — "1" against "28" — would come out ragged in an `HStack`, and the
                // filled tile marking the selection would be a different width each day of the
                // month. `DayPrayerRow` learned the same thing.
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(viewModel.week, id: \.self) { date in
                        DayTile(
                            date: date,
                            isSelected: viewModel.isSelected(date),
                            isToday: viewModel.isCurrentDay(date)
                        ) {
                            viewModel.select(date)
                        }
                    }
                }
                // Flexible columns divide whatever width they are *proposed*, and inside an
                // `HStack` that proposal is the grid's own ideal — which for seven tiles of one
                // or two digits is about half the row. So the week came out bunched against the
                // leading chevron with the trailing one stranded beside it. This is what claims
                // the space between them; the columns divide it after that.
                .frame(maxWidth: .infinity)

                pageButton(symbol: "chevron.forward", action: viewModel.showNextWeek)
                    .accessibilityLabel(l10n.string(.nextWeekAction))
            }

            HStack(spacing: AppSpacing.xs) {
                Text(HijriDateLabel.text(for: viewModel.hijriDate, l10n: l10n))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)

                if !viewModel.isToday {
                    Text(verbatim: "·")
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)

                    Button(l10n.string(.todayAction), action: viewModel.showToday)
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(theme.accent)
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: AppSpacing.xxs), count: 7)
    }

    private func pageButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(theme.accent)
                .minimumTapTarget()
        }
        .buttonStyle(.plain)
    }
}

/// One day in the strip: a letter, a numeral, and two marks that do not mean the same thing.
///
/// The **fill** is the selection — the day whose times are below. The **rule under the numeral**
/// is today, which stays marked whatever day is selected, so a reader three weeks out can still
/// see where they came from. Colour is never the only channel for either: the selected tile is
/// also the only filled one, and today's rule is a shape.
private struct DayTile: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let select: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.calendar) private var calendar

    var body: some View {
        Button(action: select) {
            VStack(spacing: 2) {
                Text(l10n.weekdayString(date))
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(isSelected ? theme.background : theme.textSecondary)

                Text(l10n.string(dayOfMonth, grouped: false))
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(isSelected ? theme.background : theme.textPrimary)
                    .monospacedDigit()

                // Drawn always and hidden when it does not apply, so the tiles keep one height
                // and the strip does not grow a point taller on whichever week contains today.
                Capsule()
                    .fill(isSelected ? theme.background : theme.accent)
                    .frame(width: 10, height: 2)
                    .opacity(isToday ? 1 : 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
            .background(isSelected ? theme.accent : .clear, in: .rect(cornerRadius: AppRadius.md))
            .contentShape(.rect(cornerRadius: AppRadius.md))
        }
        .buttonStyle(.plain)
        .minimumTapTarget()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.dateString(date))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var dayOfMonth: Int {
        calendar.component(.day, from: date)
    }
}

/// `3 / 5`, and the run of complete days behind it.
private struct TrackerHeader: View {
    let record: PrayerRecord
    let streak: Int

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(
                l10n.string(
                    .activityProgress,
                    l10n.string(record.completedCount, grouped: false),
                    l10n.string(PrayerRecord.trackable.count, grouped: false)
                )
            )

            Spacer(minLength: 8)

            if streak > 0 {
                Label(
                    l10n.string(.prayerStreakLabel, l10n.string(streak, grouped: false)),
                    systemImage: "flame"
                )
                .foregroundStyle(theme.accent)
            }
        }
        .textCase(nil)
    }
}

/// One marker: symbol, name, time, an explanation, and — for the five — a circle to mark it.
private struct PrayerDetailRow: View {
    let viewModel: PrayerTimesSheetViewModel
    let time: PrayerTime

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            StandingDot(standing: viewModel.standing(of: time))

            Text(l10n.string(time.prayer.labelKey))
                .appFont(.body)
                .foregroundStyle(theme.textPrimary)

            Button {
                viewModel.explaining = time.prayer
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.string(.aboutThisPrayerAction))

            Spacer(minLength: AppSpacing.sm)

            // The time, and under it how far off it is. Stacked rather than set beside each
            // other because the times are what the eye runs down this column for, and a second
            // figure on the same line would break the alignment that makes that possible.
            VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                Text(l10n.timeString(time.date))
                    .appFont(.body)
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()

                if let remaining = viewModel.remaining(until: time) {
                    Text(l10n.string(.inTimeLabel, l10n.countdownString(remaining)))
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
            }

            // A bell only where there is one to report — sunrise starts no prayer and so is
            // never reminded of, and a slashed bell on that row would say a reminder had been
            // switched off rather than that there was never one to switch.
            if let isReminding = viewModel.isReminding(time.prayer) {
                Image(systemName: isReminding ? "bell" : "bell.slash")
                    .appFont(.footnote)
                    .foregroundStyle(isReminding ? theme.accent : theme.separator)
                    .accessibilityLabel(
                        l10n.string(isReminding ? .reminderOnLabel : .reminderOffLabel)
                    )
            }

            // Sunrise gets no circle: it ends Fajr's window rather than starting a prayer, which
            // is the same line the reminders draw.
            if time.prayer.isObligatory {
                CompletionCircle(
                    isCompleted: viewModel.record.isCompleted(time.prayer),
                    name: l10n.string(time.prayer.labelKey)
                ) { isCompleted in
                    Task { await viewModel.setCompleted(isCompleted, of: time.prayer) }
                }
            }
        }
    }
}

/// The four states of a prayer within its day, as one dot at the head of the row.
///
/// **Never the accent alone.** The dot is one of the places the design forbids accent from
/// carrying meaning, because the accent is a choice the user makes and prayer state is not: a
/// column of dots has to read the same in amber, emerald, sapphire and rose. So *logged* is
/// Success and *passed* and *upcoming* are neutral inks, and only the one prayer being counted
/// down to takes the accent — where it means "here", the same thing it means everywhere else.
///
/// Size is the second channel, so the states are still separable in monochrome and for a reader
/// who cannot tell the greens from the greys.
private struct StandingDot: View {
    let standing: PrayerTimesSheetViewModel.Standing

    @Environment(\.theme) private var theme

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: diameter, height: diameter)
            .frame(width: 24)
            // The row says all of this in words; a dot repeated into VoiceOver is a second
            // reading of the same line.
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch standing {
        case .logged: theme.success
        case .next: theme.accent
        case .passed: theme.textSecondary.opacity(0.5)
        case .upcoming: theme.separator
        }
    }

    private var diameter: CGFloat {
        standing == .next ? 12 : 9
    }
}

/// The mark.
///
/// A `Button` drawing a circle rather than a `Toggle`: `.toggleStyle(.button)` puts the *label*
/// on screen, and `.labelsHidden()` does not apply to it — which is how a row of tick circles
/// came out as a row of prayer names in accent ink the first time this was built. The label is
/// kept for VoiceOver, where it is the only thing that identifies which circle this is.
private struct CompletionCircle: View {
    let isCompleted: Bool
    let name: String
    let setCompleted: @MainActor @Sendable (Bool) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            setCompleted(!isCompleted)
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .appFont(.title3)
                .foregroundStyle(isCompleted ? theme.accent : theme.separator)
        }
        // `.plain`, so the row's other button — the explanation — stays independently tappable.
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isCompleted ? [.isButton, .isSelected] : .isButton)
    }
}

/// Midnight and the last third, which are not prayers and so are not in the list above.
private struct NightSection: View {
    let night: NightTimes

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Section(l10n.string(.nightSectionTitle)) {
            row(.middleOfNightLabel, night.middleOfNight)
            row(.lastThirdOfNightLabel, night.lastThirdOfNight)
        }
    }

    private func row(_ key: L10nKey, _ date: Date) -> some View {
        HStack {
            Text(l10n.string(key))
                .appFont(.body)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            Text(l10n.timeString(date))
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
    }
}

private extension View {
    /// `alert(item:)` over an optional value, which SwiftUI has for sheets but not for alerts.
    func alert<Item: Identifiable>(
        item: Binding<Item?>,
        title: @escaping (Item) -> String,
        message: @escaping (Item) -> String
    ) -> some View {
        alert(
            item.wrappedValue.map(title) ?? "",
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            presenting: item.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { presented in
            Text(message(presented))
        }
    }
}
