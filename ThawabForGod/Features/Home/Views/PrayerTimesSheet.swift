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
                    DateStepper(viewModel: viewModel)
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

/// ‹ 20 August 2026 · 7 Rabi al-Awwal 1448 › with a way back to today.
private struct DateStepper: View {
    let viewModel: PrayerTimesSheetViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // `chevron.backward` and `chevron.forward`, never left and right: the semantic
                // direction flips for Arabic and the literal one does not, so "the day before"
                // stays on the side the reader expects it.
                stepButton(symbol: "chevron.backward", action: viewModel.showPreviousDay)
                    .accessibilityLabel(l10n.string(.previousDayAction))

                Spacer(minLength: 8)

                VStack(spacing: 2) {
                    Text(l10n.dateString(viewModel.day))
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(theme.textPrimary)

                    Text(HijriDateLabel.text(for: viewModel.hijriDate, l10n: l10n))
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                .multilineTextAlignment(.center)

                Spacer(minLength: 8)

                stepButton(symbol: "chevron.forward", action: viewModel.showNextDay)
                    .accessibilityLabel(l10n.string(.nextDayAction))
            }

            if !viewModel.isToday {
                Button(l10n.string(.todayAction), action: viewModel.showToday)
                    .appFont(.subheadline, weight: .medium)
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .appFont(.body, weight: .semibold)
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 12) {
            Image(systemName: time.prayer.symbol)
                .foregroundStyle(theme.accent)
                .frame(width: 24)

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

            if viewModel.upcomingPrayer == time.prayer {
                Text(l10n.string(.nextPrayerBadge))
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15), in: .capsule)
            }

            Spacer(minLength: 8)

            Text(l10n.timeString(time.date))
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()

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
