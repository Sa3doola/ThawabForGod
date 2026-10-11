//
//  QuranLibraryView.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran tab's root: the Library. A pinned header (the go-to field and the index picker) over
/// whichever of the four indexes is selected.
///
/// It is the tab's root rather than a sheet, so there is nothing to cancel and the title is inline:
/// a large title only collapses over a scroll view that starts at the top of the screen, and the
/// pinned header sits between the two.
///
/// App colours and type, not the page palette: this is an app screen, and the reader's paper is
/// something the bars take on only while the reader itself is in front.
struct QuranLibraryView: View {
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .navigationTitle(l10n.string(.quranTitle))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        coordinator.showSearch()
                    } label: {
                        Label(l10n.string(.quranSearch), systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("quran.library.search")
                }
            }
            .task(id: l10n.language) { await viewModel.load(language: l10n.language) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
        case .failed:
            QuranLoadFailureView { await viewModel.retry(language: l10n.language) }
        case .ready(let index):
            QuranLibraryContent(index: index, viewModel: viewModel, coordinator: coordinator)
        }
    }
}

/// The Library once its index exists: the header, then the one index the picker names.
private struct QuranLibraryContent: View {
    let index: QuranLibraryIndex
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator

    var body: some View {
        // The one read of the reader's live place, and only while the reader is off the stack: the
        // root stays alive under the reader, so a read made while it is pushed would re-run this
        // body on every page turn. The value goes to two places: the Continue reading bar pinned
        // under the header, and the page grid's current page. Never read `viewModel.resume`,
        // `reader.location` or `mushaf.page` anywhere else in the Library.
        let resume = coordinator.canContinueReading ? viewModel.resume : nil
        VStack(spacing: 0) {
            QuranLibraryHeader(viewModel: viewModel, coordinator: coordinator)
            // Pinned outside the lists so a scrolled list, or a grid that has scrolled itself to the
            // current page, cannot leave it off screen. Shown only while the field is empty, judged
            // on the raw text: whether a half-typed address is "filtering" changes keystroke by
            // keystroke (`2` filters, `2:` does not), and the bar would flicker and the list jump.
            if let resume, viewModel.query.isEmpty {
                QuranLibraryContinueBar(resume: resume, viewModel: viewModel, coordinator: coordinator)
            }
            switch viewModel.tab {
            case .surah:
                QuranLibrarySurahList(rows: viewModel.filteredSurahs, viewModel: viewModel, coordinator: coordinator)
            case .juz:
                QuranLibraryStartList(rows: index.juz, viewModel: viewModel, coordinator: coordinator)
            case .hizb:
                QuranLibraryHizbList(rows: index.hizb, viewModel: viewModel, coordinator: coordinator)
            case .page:
                QuranLibraryPageGrid(cells: index.pages, viewModel: viewModel, coordinator: coordinator, currentPage: resume?.page)
            }
        }
    }
}
