//
//  HomeView.swift
//  ThawabForGod
//

import SwiftUI
import TipKit // `.popoverTip(_:)`; MEMBER_IMPORT_VISIBILITY means it is not re-exported

/// Today's prayer times, with the current one marked and a countdown to the next.
///
/// The view model is injected rather than owned: the container builds it once and it outlives
/// any redraw of this view. Every colour comes from `@Environment(\.theme)`, every string and
/// digit from `LocalizationManager`, so the screen follows the accent, language and digit
/// choices without branching on any of them.
struct HomeView: View {
    let viewModel: HomeViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HijriDateHeader(viewModel: viewModel)
                content
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.homeTitle))
        // Structured concurrency does the lifecycle work: SwiftUI cancels this when the
        // screen disappears, which stops the ticking loop inside `start()`.
        .task { await viewModel.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            StatusNotice(message: l10n.string(.prayerTimesLoading), showsProgress: true)

        case .ready(let day):
            VStack(alignment: .leading, spacing: 24) {
                NextPrayerCard(viewModel: viewModel, day: day)
                    // Anchored to the card because the card is what the tip is about. A
                    // popover mirrors for Arabic without any help: it is positioned relative
                    // to its anchor view, which the layout direction has already moved.
                    .popoverTip(tomorrowsPrayerTip)
                PrayerTimesList(day: day)
            }

        case .unavailable:
            StatusNotice(message: l10n.string(.prayerTimesUnavailable), showsProgress: false)
        }
    }

    /// Built on demand rather than stored, so the copy re-resolves when the language changes —
    /// the same reason no string on this screen is held anywhere. Rebuilding is free of
    /// consequence because the tip's identity is its fixed `id`, not the instance.
    private var tomorrowsPrayerTip: HomeTomorrowsPrayerTip {
        HomeTomorrowsPrayerTip(
            titleText: l10n.string(.tipHomeTomorrowTitle),
            messageText: l10n.string(.tipHomeTomorrowMessage)
        )
    }
}

/// The loading and unavailable states, which differ only by a spinner.
private struct StatusNotice: View {
    let message: String
    let showsProgress: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            if showsProgress {
                ProgressView()
            }
            Text(message)
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()
    let engine = PrayerTimeEngine()
    let useCase = GetPrayerScheduleUseCase(repository: PrayerTimeRepository(engine: engine))

    // The preview has no `AppContainer`, so the tip datastore would be unconfigured and
    // `.popoverTip(_:)` would log its way through every redraw. `let _` because a preview body
    // is a `ViewBuilder`, which accepts declarations but not bare statements.
    let _ = TipsService().configure()

    NavigationStack {
        HomeView(
            viewModel: HomeViewModel(
                useCase: useCase,
                coordinates: .makkah,
                hijriDates: HijriDateService()
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
