//
//  HadithReadingView.swift
//  ThawabForGod
//

import SwiftUI

/// One kitab, read straight through.
///
/// **The cards are direct children of the `LazyVStack`**, which is the whole reason this screen
/// is shaped the way it is. `LazyVStack` is only lazy in the children it is given: the Quran's
/// reader learned on device that nesting a chapter inside one child builds every verse before
/// the first frame. Muslim's Book of Faith is 436 narrations, several of them a page long, so
/// the same mistake here would be considerably worse than it was there.
///
/// Nothing on this screen is customizable yet. The reader's paper, text size and line spacing
/// belong to `ReaderSettings`, which the Quran owns; sharing it is a slice of its own, and until
/// then this screen draws with the app's own type scale rather than reaching across a feature
/// boundary for a preference that was written about verses.
struct HadithReadingView: View {
    let viewModel: HadithViewModel
    let coordinator: HadithCoordinator
    let reference: BookReference

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    content
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            // Runs after the narrations are in hand, because it is keyed on the phase as well as
            // on the target: a scroll requested before the rows exist has nothing to scroll to,
            // and `ScrollViewReader` fails that silently rather than loudly.
            .task(id: scrollKey) { scroll(proxy) }
        }
        .background(theme.background)
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: reference) { await viewModel.loadReading(reference) }
        // On the way out rather than on the way in, so a kitab the reader glanced at and left is
        // still where they were — and so the write is one per visit rather than one per redraw.
        // It is deliberately not awaited here; see `HadithViewModel.recordLastRead(_:)` for what
        // stops the list underneath reading the old value back.
        .onDisappear { viewModel.recordLastRead(reference) }
    }

    /// The kitab's Arabic title once it is known, and nothing before then.
    ///
    /// Empty rather than a placeholder: a title bar that says "Loading" and then changes is a
    /// second thing moving on a screen that is already about to fill with text.
    private var title: String {
        guard case .ready(let reading) = viewModel.reading else { return "" }
        return reading.book.arabicTitle
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.reading {
        case .loading:
            ProgressView(l10n.string(.hadithLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready(let reading):
            heading(reading.book)

            ForEach(reading.hadiths) { hadith in
                HadithCard(
                    hadith: hadith,
                    isBookmarked: viewModel.isBookmarked(hadith),
                    isMemorizing: viewModel.isMemorizing(hadith),
                    onBookmark: { Task { await viewModel.toggleBookmark(hadith) } },
                    onMemorize: { Task { await viewModel.toggleMemorizing(hadith) } }
                )
                .id(hadith.id)
            }

            BookPager(previous: reading.previous, next: reading.next) { book in
                // The position is written here rather than left to `onDisappear`, which does not
                // fire when the screen stays and only its content changes. Without it a reader
                // who paged forward and closed the app would be returned to the kitab they
                // started in.
                viewModel.recordLastRead(book)
                coordinator.page(to: book)
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.hadithUnavailable))
        }
    }

    /// The kitab's English title, under the Arabic one in the navigation bar.
    ///
    /// Here rather than as a navigation subtitle, which is iOS 26. It is also the only English
    /// on this screen, and the one thing an English-reading reader can navigate by.
    private func heading(_ book: HadithBook) -> some View {
        Text(book.englishTitle)
            .appFont(.subheadline)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
    }

    // MARK: Arriving at a narration

    /// What has to be true before there is anything to scroll to: a target, and rows to find it
    /// among. Both in the key so that the scroll runs on whichever of the two arrives second.
    private var scrollKey: HadithID? {
        guard case .ready = viewModel.reading else { return nil }
        return coordinator.scrollTarget
    }

    /// Puts the reader on the narration they came for, and forgets it.
    ///
    /// Forgetting matters: a target that outlived the scroll would drag the reader back to it
    /// every time this view redrew, which on a screen they are scrolling is every frame.
    private func scroll(_ proxy: ScrollViewProxy) {
        guard let target = scrollKey else { return }

        proxy.scrollTo(target, anchor: .top)
        coordinator.clearScrollTarget()
    }
}

/// The way out of a kitab that is not Back: the two divisions either side of it.
///
/// **At the foot of the text rather than in the toolbar**, because that is where a reader who has
/// finished one arrives. A toolbar control is for something you might want at any moment; this is
/// for the one moment the last narration has been read, and putting it there means the reader
/// never has to go back up to a list to carry on.
///
/// A missing neighbour is a missing button, not a disabled one — at either end of a collection
/// there is nothing to page to, and a greyed control that can never be used is furniture.
private struct BookPager: View {
    let previous: BookReference?
    let next: BookReference?
    let open: (BookReference) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        if previous != nil || next != nil {
            HStack(spacing: AppSpacing.md) {
                if let previous {
                    button(.hadithPreviousBook, symbol: "chevron.backward", isLeading: true) {
                        open(previous)
                    }
                }

                if let next {
                    button(.hadithNextBook, symbol: "chevron.forward", isLeading: false) {
                        open(next)
                    }
                }
            }
            .padding(.top, AppSpacing.sm)
        }
    }

    /// The symbol leads on the way back and trails on the way forward, so the pair reads as an
    /// axis rather than as two unrelated buttons. `backward`/`forward` rather than `left`/`right`
    /// for the reason the day picker gives: the semantic direction flips for Arabic, the literal
    /// one does not.
    private func button(
        _ key: L10nKey,
        symbol: String,
        isLeading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLeading { Image(systemName: symbol) }
                Text(l10n.string(key))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !isLeading { Image(systemName: symbol) }
            }
            .appFont(.subheadline, weight: .semibold)
            .foregroundStyle(theme.accent)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)
            .appCard()
            .appHover()
        }
        .buttonStyle(.plain)
    }
}
