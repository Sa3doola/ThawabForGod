//
//  AdhkarReadingView.swift
//  ThawabForGod
//

import SwiftUI

/// One chapter's adhkar, read one at a time.
///
/// **A pager rather than a scrolling column, and the counter is why.** The adhkar are not a page
/// to be read down; they are a sequence of things to be *said*, most of them once and some of them
/// a hundred times. In a column the control that counts moved with the text — so on a long dhikr
/// it sat below the fold, and counting to a hundred meant scrolling back to it between
/// recitations. Here the card is one screenful and the counter is pinned under it, so the reader's
/// thumb has one place to be from the first dhikr to the last.
///
/// **It advances itself.** Finishing a dhikr moves to the next one after a beat. That is new with
/// the full corpus and it is the difference between a screen a reader works and a screen that
/// works: 79 of the 132 chapters hold a single dhikr and are done in one tap, but the ones that
/// matter most — the morning and evening adhkar, 24 of them — are two dozen taps and two dozen
/// swipes without it, and the swipe is the half a reader with a phone in one hand keeps missing.
/// The beat before the move is not decoration: it is the time the completed state needs to be
/// seen, or the reader is left unsure whether the tap registered.
///
/// The last dhikr does not advance to anything. It banks, and the strip above turns over to say
/// the chapter is finished — which is the only completion state this screen has, and it belongs at
/// the top where it stays put rather than on a card that is about to be swiped away.
struct AdhkarReadingView: View {
    let viewModel: AdhkarViewModel
    /// The chapter's slug. A string rather than an `AdhkarCategory` because this screen is
    /// reachable from a deep link — see `AdhkarCoordinator`.
    let categoryID: String

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Which dhikr is on screen. The id rather than an index, because the array is re-fetched
    /// whenever the task re-runs and an index into the old one would be a different dhikr.
    @State private var current: Int?

    /// Bumped every time a dhikr is completed, and read only by `.sensoryFeedback`.
    ///
    /// A counter rather than a `Bool`, because two dhikr finished in a row are two events and a
    /// flag would only change once. Nothing draws it.
    @State private var completions = 0

    /// Bumped on every counted recitation, for the lighter of the two haptics.
    @State private var taps = 0

    var body: some View {
        content
            .background(theme.background)
            .navigationTitle(viewModel.category?.title(in: l10n.language) ?? l10n.string(.adhkarTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
            // Keyed on the slug so that arriving at a different chapter — which a deep link can
            // do without this screen being torn down — re-runs the load. SwiftUI owns the task's
            // lifetime and cancels it when the screen goes away.
            .task(id: categoryID) { await viewModel.load(categoryID: categoryID) }
            // Two feedbacks, on two different events. The tap is the lighter of the pair and
            // fires on every count; the completion is the heavier and fires on the crossing —
            // which is why both are driven by a counter that is incremented at the moment, rather
            // than by a state a redraw could re-trigger. The same distinction the Qibla's
            // alignment ring draws.
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
            .sensoryFeedback(.success, trigger: completions)
            // Home's recent-activity chip is written on a delay, so a reader who counts a dhikr
            // and leaves in the same breath would otherwise lose the last count. Unstructured on
            // purpose: the recorder outlives this screen, which is the whole point of flushing
            // from here.
            .onDisappear {
                Task { await viewModel.flushActivity() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.readingPhase {
        case .loading:
            notice { ProgressView(l10n.string(.adhkarLoading)).appFont(.callout) }

        case .ready(let adhkar) where adhkar.isEmpty:
            notice { InlineNotice(message: l10n.string(.adhkarEmpty)) }

        case .ready(let adhkar):
            reader(adhkar)

        case .unavailable:
            notice { InlineNotice(message: l10n.string(.adhkarUnavailable)) }
        }
    }

    private func notice<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundStyle(theme.textSecondary)
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: The reader

    private func reader(_ adhkar: [Dhikr]) -> some View {
        arrangement(adhkar)
            // The selection has to exist before the pager is laid out or it opens on nothing.
            // First dhikr rather than the first *incomplete* one: a reader opening a chapter means
            // to say it, not to resume a tally.
            .task(id: adhkar.first?.id) { current = adhkar.first?.id }
    }

    /// The words and the counter, as one column or as two regions.
    ///
    /// **Two regions at regular width, and iPhone Duo's inner display is why.** Its fold runs down
    /// the middle of the screen, and the column this screen draws is centred — so opened flat, the
    /// dhikr and the counter both straddled the crease, and in a book-like pose each was bent
    /// across it. `ArrangementView` is the system's container for exactly this shape of screen:
    /// two peers, neither on top of the other, and it keeps the split clear of the fold rather than
    /// this screen having to find it. The axes are left free, so wherever the words and counter
    /// fit better one above the other, they go one above the other.
    ///
    /// The branch is on the size class, not on the device: the same regular width on an iPad gets
    /// the same two regions. Everything that must survive the switch — which dhikr is on screen,
    /// the counts — is owned above it, so unfolding the phone rebuilds the regions without moving
    /// the reader.
    @ViewBuilder
    private func arrangement(_ adhkar: [Dhikr]) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *), horizontalSizeClass == .regular {
            // The counter leads and the words trail, which reads backwards and is not. With the
            // sidebar showing, the leading half of the screen is mostly sidebar — the words in it
            // were measured on the device at three to a line, with the pips squeezed out of
            // existence — while the trailing half is a whole half. And the trailing half is the
            // one Apple's guidance gives continuity to: it is what stays in front of the reader as
            // a book-like pose closes toward the outer display.
            ArrangementView {
                // At the foot of its region: that is where a thumb already is, and in a
                // table-like pose it is the half lying flat on the table.
                counter(adhkar, resetPlacement: .vertical)
                    .padding(AppSpacing.xl)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            } secondary: {
                VStack(spacing: AppSpacing.lg) {
                    header(adhkar)
                    pager(adhkar)
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: AppBreakpoint.readingMeasure)
                .frame(maxWidth: .infinity)
                // The words before the control that counts them, whatever side each is drawn on.
                .accessibilitySortPriority(1)
            }
            .arrangementViewStyle(.split)
        } else {
            column(adhkar)
        }
        #else
        column(adhkar)
        #endif
    }

    /// Words above, counter under them — the compact layout, and every OS before 27.1.
    private func column(_ adhkar: [Dhikr]) -> some View {
        VStack(spacing: AppSpacing.lg) {
            header(adhkar)
            pager(adhkar)
            counter(adhkar)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: AppBreakpoint.readingMeasure)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func counter(_ adhkar: [Dhikr], resetPlacement: Axis = .horizontal) -> some View {
        if let dhikr = currentDhikr(in: adhkar) {
            RepeatCounter(
                counted: viewModel.repeats(of: dhikr),
                target: dhikr.repeatCount,
                onCount: { count(dhikr, in: adhkar) },
                onReset: { viewModel.resetRepeats(of: dhikr) },
                resetPlacement: resetPlacement
            )
        }
    }

    /// The strip above the card: where the reader is, or that they are finished.
    ///
    /// One line rather than two, and it swaps rather than stacking, because the two say the same
    /// thing at different moments — while there is anything left the pips are the answer, and once
    /// there is not, the pips are a row of identical marks and the words are.
    ///
    /// **The tally sits here rather than in the toolbar**, where it began. A navigation bar gives
    /// its trailing item whatever the title has not taken, and these titles are chapter headings —
    /// أذكار الصباح والمساء is most of a phone's width — so the number was being squeezed out of
    /// existence on exactly the chapters long enough to need it. Beside the pips it is also where
    /// it belongs: the shape and the number are one statement, and the pips are what a glance
    /// reads while the number is what a reader checks.
    @ViewBuilder
    private func header(_ adhkar: [Dhikr]) -> some View {
        if viewModel.isChapterComplete {
            Label(l10n.string(.adhkarChapterComplete), systemImage: "checkmark.seal.fill")
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(theme.success)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        } else if adhkar.count > 1 {
            HStack(spacing: AppSpacing.md) {
                PipStrip(adhkar: adhkar, current: current, isComplete: viewModel.isComplete)

                Text(tally)
                    .appFont(.footnote, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
                    // Held to its own width so the pips do not resize under the reader every time
                    // a count lands and 9 becomes 10.
                    .fixedSize()
                    .accessibilityLabel(l10n.string(.adhkarProgressLabel))
                    .accessibilityValue(tally)
            }
        }
    }

    /// One card at a time, paged by a swipe.
    ///
    /// A horizontal `ScrollView` with `.paging` rather than `TabView(.page)`, because the page
    /// style is iOS-only and this screen is on the Mac too. It also mirrors for Arabic without
    /// help, which a `TabView` does not — and the vertical scroll *inside* each page is what lets
    /// a long dhikr still be read at a large text size on a small phone.
    private func pager(_ adhkar: [Dhikr]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: AppSpacing.xl) {
                ForEach(Array(adhkar.enumerated()), id: \.element.id) { index, dhikr in
                    ScrollView(.vertical) {
                        DhikrCard(
                            dhikr: dhikr,
                            // Suppressed in a chapter of one: "dhikr 1" above the only dhikr
                            // there is says nothing, and 79 of the 132 chapters are that shape.
                            position: adhkar.count > 1 ? index + 1 : nil,
                            textSize: viewModel.textSize
                        )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .containerRelativeFrame(.horizontal)
                    .id(dhikr.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $current)
        // Without this the pages are cut off at the padding rather than at the screen's edge,
        // and the neighbouring card peeks in from the side mid-swipe.
        .contentMargins(.horizontal, 0, for: .scrollContent)
        // The pager is one horizontally-scrolling element to VoiceOver, which would otherwise
        // read every card in the chapter as if they were all on screen.
        .accessibilityElement(children: .contain)
    }

    private func currentDhikr(in adhkar: [Dhikr]) -> Dhikr? {
        adhkar.first { $0.id == current } ?? adhkar.first
    }

    /// One recitation, and whatever follows from it.
    ///
    /// The move to the next dhikr is a plain `Task` rather than anything stored: if the reader
    /// swipes in the meantime, `current` has already changed and the guard below leaves it alone,
    /// so a late advance can never take a card out from under them.
    private func count(_ dhikr: Dhikr, in adhkar: [Dhikr]) {
        taps += 1
        guard viewModel.countRepeat(of: dhikr) else { return }

        completions += 1
        guard let next = viewModel.dhikr(after: dhikr) else { return }

        Task {
            try? await Task.sleep(for: .milliseconds(550))
            guard current == dhikr.id else { return }
            withAnimation(.snappy) { current = next.id }
        }
    }

    // MARK: The toolbar

    /// One control: how large the words are. The tally moved down beside the pips — see
    /// `header(_:)`.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) { textSizeMenu }
    }

    /// How large the words are set.
    ///
    /// A menu rather than a pair of toolbar buttons, because these titles are chapter headings and
    /// a navigation bar gives its trailing items whatever the title has not taken — one item fits
    /// where two do not.
    ///
    /// **Both rows say which way they go, in words.** They began as two `textformat.size.larger` /
    /// `.smaller` labels both reading "Text size", which renders as two identical rows with two
    /// near-identical letter As beside them — a menu the reader has to guess at, which is the
    /// failure the Mac panel's footer already learned once. `plus`/`minus` are the two glyphs in
    /// the set that cannot be mistaken for each other at menu size.
    ///
    /// Each row disables at its end of the range, so the control says where the limits are instead
    /// of silently doing nothing.
    private var textSizeMenu: some View {
        Menu {
            Button {
                viewModel.enlargeText()
            } label: {
                Label(l10n.string(.adhkarTextLarger), systemImage: "plus.magnifyingglass")
            }
            .disabled(!viewModel.canEnlargeText)

            Button {
                viewModel.shrinkText()
            } label: {
                Label(l10n.string(.adhkarTextSmaller), systemImage: "minus.magnifyingglass")
            }
            .disabled(!viewModel.canShrinkText)
        } label: {
            Label(l10n.string(.adhkarTextSize), systemImage: "textformat.size")
        }
    }

    /// How far through the chapter the reader is.
    ///
    /// Both numbers go through `LocalizationManager`, ungrouped — they count items, and a
    /// thousands separator would be wrong at any size a chapter will ever reach.
    private var tally: String {
        let done = l10n.string(viewModel.completedCount, grouped: false)
        let total = l10n.string(viewModel.totalCount, grouped: false)
        return "\(done) / \(total)"
    }
}

/// One segment per dhikr, filled as each is finished.
///
/// **A progress bar cut into pieces, rather than a bar and a number.** A single bar would say how
/// far through the reader is and nothing about how much is left to do at this moment; the segments
/// say both, because a chapter of five and a chapter of twenty-four look different before a single
/// one is counted. The current dhikr is picked out so the strip is also a position.
private struct PipStrip: View {
    let adhkar: [Dhikr]
    let current: Int?
    let isComplete: (Dhikr) -> Bool

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            ForEach(adhkar) { dhikr in
                Capsule()
                    .fill(fill(for: dhikr))
                    .frame(height: 4)
            }
        }
        .animation(.snappy, value: current)
        // The strip restates the toolbar's tally and the card's kicker, both of which VoiceOver
        // already reads. A row of twenty-four unlabelled shapes would be noise.
        .accessibilityHidden(true)
    }

    private func fill(for dhikr: Dhikr) -> Color {
        if isComplete(dhikr) { return theme.success }
        if dhikr.id == current { return theme.accent }
        return theme.separator
    }
}

#Preview("A chapter of many") {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        AdhkarReadingView(
            viewModel: AdhkarViewModel(
                useCase: GetAdhkarUseCase(
                    repository: AdhkarRepository(database: CorpusDatabase(name: "corpus"))
                ),
                settingsStore: settingsStore
            ),
            categoryID: AdhkarCategory.morningAndEveningID
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

#Preview("A chapter of one") {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        AdhkarReadingView(
            viewModel: AdhkarViewModel(
                useCase: GetAdhkarUseCase(
                    repository: AdhkarRepository(database: CorpusDatabase(name: "corpus"))
                ),
                settingsStore: settingsStore
            ),
            categoryID: "entering-the-market"
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
