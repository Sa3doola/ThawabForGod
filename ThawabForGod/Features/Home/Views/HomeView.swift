//
//  HomeView.swift
//  ThawabForGod
//

import SwiftUI
import TipKit // `.popoverTip(_:)`; MEMBER_IMPORT_VISIBILITY means it is not re-exported

/// Home: a header, and then whatever the user has arranged below it.
///
/// **The stack is data, not code.** The order and the membership come from `HomeLayout`, which
/// the user edits in the customization screen, so this view iterates a list of kinds and switches
/// over it rather than hard-coding a sequence of cards. That is what makes adding a section a new
/// case here plus a case in the enum — and what makes hiding one a preference rather than a
/// branch.
///
/// The `switch` is a `@ViewBuilder`, never `AnyView`: the branches have different types and that
/// is fine, because SwiftUI's builder is built for exactly this and erasing them would throw away
/// the identity that keeps each section's state across a redraw.
///
/// A `LazyVStack` rather than a `VStack`, so a section scrolled off the bottom of a long
/// arrangement is not built until it is reached.
struct HomeView: View {
    let viewModel: HomeViewModel

    /// Where a tap goes. A plain closure rather than a coordinator, because Home's sections open
    /// screens in three different tabs and a view that knew that would be a feature knowing the
    /// shape of the whole app — see `AppRoute`.
    let open: (AppRoute) -> Void

    /// Opens the screen where this stack is arranged.
    ///
    /// Separate from `open` because it is not a route: every `AppRoute` lands in some tab's own
    /// stack, and this one is pushed onto whichever stack Home happens to be in.
    let customize: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HomeHeader(viewModel: viewModel)

                ForEach(viewModel.sections, id: \.self) { kind in
                    section(for: kind)
                }
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        // "Home", not "Prayer Times": the screen stopped being only prayer times when it became
        // a stack the user arranges, and the header's greeting is what titles it now.
        .navigationTitle(l10n.string(.homeTabLabel))
        // Inline on iOS, so the large-title band does not sit above a greeting that is already
        // doing that job — on a 4.7-inch phone it was a hundred points of saying it twice.
        // macOS has no such modifier, and no large title to suppress.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Structured concurrency does the lifecycle work: SwiftUI cancels this when the
        // screen disappears, which stops the ticking loop inside `start()`.
        .task { await viewModel.start() }
        // Settings can change the calculation method while this screen is still alive behind
        // it. The ticking loop would not notice — it only recomputes when a prayer arrives —
        // so the change is watched here and the times are recomputed on the spot.
        .onChange(of: viewModel.config) { viewModel.refresh() }
        // A phone that was locked overnight comes back to a card built before midnight. The
        // heartbeat notices that too — see `tick()` — but only on its next beat, and returning
        // to a stale screen for a second is exactly the moment somebody looks at it.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refresh()
        }
    }

    /// One section of the stack.
    ///
    /// Every case of `HomeSectionKind` is answered here, including the ones whose features do not
    /// exist yet. `lastActivity` is the next slice; the rest are reserved and filtered out of
    /// `viewModel.sections` by `isAvailable` before they ever reach this.
    @ViewBuilder
    private func section(for kind: HomeSectionKind) -> some View {
        switch kind {
        case .nextPrayer:
            nextPrayer

        case .continueReading:
            if let reading = viewModel.continueReading {
                ContinueReadingSection(reading: reading, open: open)
            }

        case .shortcuts:
            ShortcutsSection(
                shortcuts: viewModel.shortcuts,
                open: open,
                edit: customize
            )

        case .lastActivity, .prayerTracker,
             .islamicCalendar, .ayahOfDay, .hadithOfDay, .duaOfDay:
            EmptyView()
        }
    }

    /// The pinned card, which is the one section with a loading and a failure state of its own —
    /// everything else on this screen either has something to show or is absent.
    @ViewBuilder
    private var nextPrayer: some View {
        switch viewModel.phase {
        case .loading:
            StatusNotice(message: l10n.string(.prayerTimesLoading), showsProgress: true)

        case .ready(let state):
            NextPrayerCard(viewModel: viewModel, state: state)
                // Anchored to the card because the card is what the tip is about. A popover
                // mirrors for Arabic without any help: it is positioned relative to its anchor
                // view, which the layout direction has already moved.
                .popoverTip(tomorrowsPrayerTip)

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
                getLayout: GetHomeLayoutUseCase(
                    repository: HomeLayoutRepository(settingsStore: settingsStore)
                ),
                coordinates: .makkah,
                hijriDates: HijriDateService(),
                calculation: CalculationSettings(config: .default, settingsStore: settingsStore)
            ),
            open: { _ in },
            customize: {}
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
