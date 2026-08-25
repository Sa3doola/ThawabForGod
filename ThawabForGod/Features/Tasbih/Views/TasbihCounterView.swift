//
//  TasbihCounterView.swift
//  ThawabForGod
//

import SwiftUI
import TipKit

/// The counter itself: one phrase, one disc, and two numbers under it.
///
/// Deliberately sparse. This is a screen someone uses with their eyes half on it, so everything
/// that is not the count, the phrase or the lap tally has been left off.
struct TasbihCounterView: View {
    let viewModel: TasbihViewModel
    let dhikr: TasbihDhikr

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                phrase
                counter
                LapProgress(target: viewModel.targetCount, completedLaps: viewModel.completedLaps)
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.tasbihTitle))
        // Restores whatever was counted for this preset before. Keyed on the dhikr so choosing a
        // different one from the list re-runs it rather than leaving the old session on screen.
        .task(id: dhikr.id) { await viewModel.select(dhikr) }
        // The two ways a count can be abandoned. Both are cheap to call and idempotent, so
        // neither has to know the other exists.
        .onDisappear(perform: savePendingCount)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { savePendingCount() }
        }
        // One tap, one bump. Triggered on the *total* rather than the current count, because the
        // current one falls back to zero at a lap boundary and would read as a change in the
        // wrong direction — and a reset would fire a phantom tap.
        .sensoryFeedback(trigger: viewModel.totalCount) { previous, current in
            current > previous ? .impact(weight: .medium) : nil
        }
        // And something distinctly different for finishing a lap. Guarded the same way so
        // resetting, which zeroes the lap count, stays silent.
        .sensoryFeedback(trigger: viewModel.completedLaps) { previous, current in
            current > previous ? .success : nil
        }
    }

    /// The dhikr being counted.
    ///
    /// Forced right-to-left rather than left to inherit the screen's direction: the phrase is
    /// Arabic whatever language the interface is in.
    private var phrase: some View {
        VStack(spacing: 8) {
            Text(dhikr.arabicText)
                .appFont(.title, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, AppLanguage.arabic.locale)

            if let translation = dhikr.translation {
                Text(translation)
                    .appFont(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private var counter: some View {
        CounterButton(
            count: viewModel.currentCount,
            target: viewModel.targetCount,
            progress: viewModel.lapProgress,
            onCount: viewModel.increment,
            onReset: { Task { await viewModel.reset() } }
        )
        .popoverTip(resetTip)
    }

    /// Rebuilt on each redraw so the copy follows a language change. Safe because the tip's
    /// identity is its fixed `id`, not the instance — see `TasbihTips`.
    private var resetTip: TasbihResetTip {
        TasbihResetTip(
            titleText: l10n.string(.tipTasbihResetTitle),
            messageText: l10n.string(.tipTasbihResetMessage)
        )
    }

    /// Unstructured on purpose: the write has to outlive the view that is going away, so it must
    /// not be tied to a `.task` SwiftUI is about to cancel.
    private func savePendingCount() {
        Task { await viewModel.persistPendingCount() }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        TasbihCounterView(
            viewModel: previewTasbihViewModel(),
            dhikr: TasbihDhikr(
                id: "subhanallah",
                arabicText: "سُبْحَانَ اللَّهِ",
                translation: "Glory be to Allah",
                targetCount: 33
            )
        )
    }
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
