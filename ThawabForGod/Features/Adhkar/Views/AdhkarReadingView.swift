//
//  AdhkarReadingView.swift
//  ThawabForGod
//

import SwiftUI

/// One category's adhkar, read one at a time.
///
/// **A pager rather than the scrolling column this replaced, and the counter is why.** The adhkar
/// are not a page to be read down; they are a sequence of things to be *said*, most of them
/// several times over and one of them a hundred. In a column the control that counts moved with
/// the text — so on a long dhikr it sat below the fold, and counting to a hundred meant scrolling
/// back to it between recitations. Here the card is one screenful and the counter is pinned under
/// it, so the reader's thumb has one place to be from the first dhikr to the last.
///
/// It also gives the screen an answer to "how far through am I?" that a scroll bar cannot: the
/// pips are one segment per dhikr, filled as each is completed.
///
/// The reload is keyed on the language rather than run once: changing language while the screen
/// is open re-fetches the translations and the citations in the new one, and because the counts
/// live in the view model rather than in these rows, the reader keeps their place through it.
struct AdhkarReadingView: View {
    let viewModel: AdhkarViewModel
    let category: AdhkarCategory

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// The reader's choice of what to see beside the Arabic, for this visit. Local `@State`
    /// because it is a preference about *this screen* — the view model is about the adhkar.
    @State private var showsTranslation = true
    @State private var showsTransliteration = false

    /// Which dhikr is on screen. The id rather than an index, because the array is re-fetched on
    /// a language change and an index into the old one would be a different dhikr in the new.
    @State private var current: Int?

    var body: some View {
        content
            .background(theme.background)
            .navigationTitle(l10n.string(category.titleKey))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
            // SwiftUI cancels and re-runs this when the language changes, which is exactly the
            // re-fetch that is wanted — and cancels it outright when the screen goes away.
            .task(id: l10n.language) {
                await viewModel.load(category, language: l10n.language)
            }
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
        VStack(spacing: AppSpacing.lg) {
            PipStrip(adhkar: adhkar, current: current) { viewModel.repeats(of: $0) >= $0.repeatCount }

            pager(adhkar)

            if let dhikr = currentDhikr(in: adhkar) {
                VStack(spacing: AppSpacing.sm) {
                    RepeatCounter(
                        counted: viewModel.repeats(of: dhikr),
                        target: dhikr.repeatCount,
                        onCount: { viewModel.countRepeat(of: dhikr) },
                        onReset: { viewModel.resetRepeats(of: dhikr) }
                    )

                    // Said once, under the control, rather than left to be discovered: a card
                    // that pages on a swipe and nowhere says so is a card most readers will
                    // scroll at and give up on.
                    if adhkar.count > 1 {
                        Text(l10n.string(.adhkarSwipeHint))
                            .appFont(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, alignment: .center)
        // The selection has to exist before the pager is laid out or it opens on nothing. First
        // dhikr rather than the first *incomplete* one: a reader opening the morning adhkar
        // means to say them, not to resume a tally from yesterday.
        .task(id: adhkar.first?.id) { current = current ?? adhkar.first?.id }
    }

    /// One card at a time, paged by a swipe.
    ///
    /// A horizontal `ScrollView` with `.paging` rather than `TabView(.page)`, because the page
    /// style is iOS-only and this screen is on the Mac too. It also mirrors for Arabic without
    /// help, which a `TabView` does not — and the vertical scroll *inside* each page is what lets
    /// a long dhikr with a virtue attached still be read on a small phone.
    private func pager(_ adhkar: [Dhikr]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: AppSpacing.xl) {
                ForEach(adhkar) { dhikr in
                    ScrollView(.vertical) {
                        DhikrCard(
                            dhikr: dhikr,
                            position: (adhkar.firstIndex(of: dhikr) ?? 0) + 1,
                            counted: viewModel.repeats(of: dhikr),
                            showsTranslation: showsTranslation,
                            showsTransliteration: showsTransliteration
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
    }

    private func currentDhikr(in adhkar: [Dhikr]) -> Dhikr? {
        adhkar.first { $0.id == current } ?? adhkar.first
    }

    // MARK: The toolbar

    /// The tally, and the two display switches.
    ///
    /// In the toolbar rather than on the page, which is where they used to be: as a card of
    /// toggles above the text they cost a third of a phone's screen for a choice most readers
    /// make once and never revisit. The menu is one glyph, and the tally beside it is the number
    /// the pips draw as a shape.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: AppSpacing.sm) {
                Text(tally)
                    .appFont(.subheadline, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(
                        viewModel.completedCount == viewModel.totalCount
                            ? theme.success
                            : theme.textSecondary
                    )
                    .accessibilityLabel(l10n.string(.adhkarProgressLabel))
                    .accessibilityValue(tally)

                if offersTranslation {
                    displayMenu
                }
            }
        }
    }

    /// What to show beside the Arabic. Absent entirely for an Arabic reader, for whom there is
    /// no translation and nothing to transliterate into.
    private var displayMenu: some View {
        Menu {
            Toggle(l10n.string(.adhkarShowTranslation), isOn: $showsTranslation)

            if offersTransliteration {
                Toggle(l10n.string(.adhkarShowTransliteration), isOn: $showsTransliteration)
            }
        } label: {
            Label(l10n.string(.adhkarShowTranslation), systemImage: "textformat")
        }
    }

    private var offersTranslation: Bool {
        guard case .ready(let adhkar) = viewModel.readingPhase else { return false }
        return adhkar.contains { $0.translation != nil }
    }

    private var offersTransliteration: Bool {
        guard case .ready(let adhkar) = viewModel.readingPhase else { return false }
        return adhkar.contains { $0.transliteration != nil }
    }

    /// How far through the category the reader is.
    ///
    /// Both numbers go through `LocalizationManager`, ungrouped — they count items, and a
    /// thousands separator would be wrong at any size the corpus will ever reach.
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
/// say both, because a category of five and a category of thirty-three look different before a
/// single one is counted. The current dhikr is picked out so the strip is also a position.
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
        // The strip restates the toolbar's tally and the card's kicker, both of which VoiceOver
        // already reads. A row of thirty-three unlabelled shapes would be noise.
        .accessibilityHidden(true)
    }

    private func fill(for dhikr: Dhikr) -> Color {
        if isComplete(dhikr) { return theme.success }
        if dhikr.id == current { return theme.accent }
        return theme.separator
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        AdhkarReadingView(
            viewModel: AdhkarViewModel(
                useCase: GetAdhkarUseCase(
                    repository: AdhkarRepository(database: CorpusDatabase(name: "corpus"))
                )
            ),
            category: .morning
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
