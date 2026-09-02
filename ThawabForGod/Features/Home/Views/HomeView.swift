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

    /// Opens the day sheet — the full day, for any day.
    let showPrayerTimes: () -> Void

    /// Whether that sheet is up. A binding rather than a callback, because a sheet is dismissed
    /// by the system as well as by the app and both have to reach the same value.
    @Binding var isShowingPrayerTimes: Bool

    /// Opens the screen where this stack is arranged.
    ///
    /// Separate from `open` because it is not a route: every `AppRoute` lands in some tab's own
    /// stack, and this one is pushed onto whichever stack Home happens to be in.
    let customize: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // The width the *cards* get, which is what decides whether this is a stack or a board —
        // not the size class, which cannot tell an iPad in a half-width Split View from a phone.
        // See `AppBreakpoint`.
        GeometryReader { proxy in
            ScrollView {
                stack(width: proxy.size.width)
                    .padding(AppSpacing.xl)
                    .frame(maxWidth: measure(width: proxy.size.width), alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
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
        // The sheet marks past days *and* today, so the row of circles behind it can be out of
        // date by the time it is gone.
        .onChange(of: isShowingPrayerTimes) { _, isShowing in
            guard !isShowing else { return }
            Task { await viewModel.reloadTracker() }
        }
    }

    /// The whole arrangement: a single column, or the board.
    ///
    /// **The hero spans the board and everything else flows around it.** A countdown in a
    /// half-width column on a 1024-point iPad is a countdown nobody can read from across a room,
    /// which is the one thing this screen exists to be. `HomeLayout` guarantees the pinned
    /// section is first and cannot be hidden, so the split is a filter rather than a search.
    @ViewBuilder
    private func stack(width: CGFloat) -> some View {
        let columns = AppBreakpoint.homeBoardColumns(
            width: width,
            isAccessibilitySize: typeSize.isAccessibilitySize
        )

        let pairs = AppBreakpoint.homeCardsPair(
            width: width,
            isAccessibilitySize: typeSize.isAccessibilitySize
        )

        LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
            HomeHeader(viewModel: viewModel)

            if columns > 1 {
                ForEach(pinnedSections, id: \.self) { section(for: $0) }
                board
            } else if pairs {
                ForEach(pairedRows, id: \.self) { row in
                    pairedRow(row)
                }
            } else {
                ForEach(viewModel.sections, id: \.self) { section(for: $0) }
            }
        }
    }

    /// The middle arrangement: the stack in order, with any two adjacent pairable cards drawn
    /// side by side.
    ///
    /// **Adjacent, and in the arrangement's own order** — not "the tracker and the continue
    /// card, wherever they are". Pulling two sections together across a third would reorder a
    /// stack the user arranged by hand, which is the one thing this screen promised not to do;
    /// somebody who put recent activity between them meant it there. So a pair forms only where
    /// the arrangement already has two of them touching, which on a default layout is exactly
    /// the pair the design draws.
    private var pairedRows: [[HomeSectionKind]] {
        var rows: [[HomeSectionKind]] = []

        for kind in renderableSections {
            // Extend the row in progress if it has room and this card can take half a width.
            if kind.canPair,
               var last = rows.last,
               last.count == 1,
               last[0].canPair {
                last.append(kind)
                rows[rows.count - 1] = last
            } else {
                rows.append([kind])
            }
        }

        return rows
    }

    /// One row of the middle arrangement — a single card, or two sharing the width.
    ///
    /// `.top` alignment, because the two cards are short but not identically short: aligning
    /// their centres would leave the shorter one floating against the taller, which reads as a
    /// mistake rather than as a pair.
    @ViewBuilder
    private func pairedRow(_ row: [HomeSectionKind]) -> some View {
        if row.count > 1 {
            HStack(alignment: .top, spacing: AppSpacing.lg) {
                ForEach(row, id: \.self) { kind in
                    section(for: kind)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else if let kind = row.first {
            section(for: kind)
        }
    }

    /// Two columns of cards, dealt alternately rather than laid out in rows.
    ///
    /// A `LazyVGrid` would give every row the height of its tallest cell, so a short tracker
    /// beside a long recent-activity list would sit above a band of nothing — which is exactly
    /// what the design does *not* draw. Two stacks side by side is the board it does draw, and
    /// the deal is by index so it is stable: reordering the cards moves them, but nothing moves
    /// on its own between redraws.
    private var board: some View {
        HStack(alignment: .top, spacing: AppSpacing.lg) {
            ForEach(0..<2, id: \.self) { column in
                LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                    ForEach(flowingSections(in: column), id: \.self) { section(for: $0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var pinnedSections: [HomeSectionKind] {
        viewModel.sections.filter(\.isPinned)
    }

    private func flowingSections(in column: Int) -> [HomeSectionKind] {
        renderableSections
            .filter { !$0.isPinned }
            .enumerated()
            .filter { $0.offset % 2 == column }
            .map(\.element)
    }

    /// The arrangement, minus the sections that would draw nothing.
    ///
    /// Two sections are conditional on having something to say — "continue reading" before
    /// anything has been read, recent activity before anything has been done — and in a single
    /// column an empty one costs nothing, because a view that draws nothing takes no room.
    ///
    /// **In any arrangement that puts cards beside each other it costs a hole.** A pair whose
    /// second half is an empty continue-reading card is a tracker at half width with a blank
    /// space next to it, and in the board it is a column dealt one card light. So the emptiness
    /// is resolved here, once, before the layout counts anything — rather than by each
    /// arrangement discovering it downstream.
    ///
    /// The conditions are the same ones `section(for:)` applies; they are stated twice because
    /// the alternative is a view that returns an optional and a layout that has to build it to
    /// find out, which would defeat the `LazyVStack` above.
    private var renderableSections: [HomeSectionKind] {
        viewModel.sections.filter { kind in
            switch kind {
            case .continueReading: viewModel.continueReading != nil
            case .lastActivity: !viewModel.recentActivities.isEmpty
            default: true
            }
        }
    }

    /// How wide the content is allowed to get before it centres instead of stretching.
    ///
    /// Two numbers, because a board and a stack are answering different questions: one column of
    /// cards past about 560 points is a row of very wide rows, while a two-column board wants the
    /// room. Both still centre in whatever is left, so the Mac's window can be dragged to any
    /// width without the content ever hanging off one edge.
    private func measure(width: CGFloat) -> CGFloat {
        let columns = AppBreakpoint.homeBoardColumns(
            width: width,
            isAccessibilitySize: typeSize.isAccessibilitySize
        )

        return columns > 1 ? AppBreakpoint.fourColumn : AppBreakpoint.contentMeasure
    }

    /// One section of the stack.
    ///
    /// Every case of `HomeSectionKind` is answered here, including the reserved ones — which are
    /// filtered out of `viewModel.sections` by `isAvailable` before they ever reach this, so
    /// those branches are unreachable rather than merely unused.
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

        case .lastActivity:
            // Absent, not empty. A user who has done none of the three sees no heading rather
            // than a heading with nothing under it — the same rule "continue reading" follows.
            if !viewModel.recentActivities.isEmpty {
                RecentActivitySection(items: viewModel.recentActivities, open: open)
            }

        case .prayerTracker:
            PrayerTrackerSection(
                record: viewModel.todaysPrayers,
                streak: viewModel.prayerStreak
            ) { prayer, isCompleted in
                Task { await viewModel.setPrayerCompleted(isCompleted, of: prayer) }
            }

        case .islamicCalendar, .ayahOfDay, .hadithOfDay, .duaOfDay:
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
            NextPrayerCard(viewModel: viewModel, state: state, open: showPrayerTimes)
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
            showPrayerTimes: {},
            isShowingPrayerTimes: .constant(false),
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
