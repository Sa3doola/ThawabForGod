//
//  QuranLibraryIndexViews.swift
//  ThawabForGod
//

import SwiftUI

// The Library's four indexes. Each is handed its rows; none of them reads the reader's live place
// (the Page grid is given the current page as a value, and Continue reading is pinned above them
// by `QuranLibraryContinueBar`), and none decides which build it is in: a Page grid is only ever
// given cells because the index only ever builds them where there are pages.
//
// A row's action is always the view model's `didOpen()` (the field is cleared, as Mushaf's sheet
// was dismissed) followed by the coordinator opening the row's target.

/// The 114 surahs, narrowed by the field when a number or a name is typed.
struct QuranLibrarySurahList: View {
    let rows: [QuranLibrarySurahRow]
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            ForEach(rows) { row in
                surahRow(row)
            }
        }
        .quranLibraryList()
        .overlay { emptyMessage }
    }

    private func surahRow(_ row: QuranLibrarySurahRow) -> some View {
        let number = row.surah.number
        return Button {
            viewModel.didOpen()
            coordinator.open(.surah(number))
        } label: {
            QuranLibrarySurahRowView(row: row)
        }
        .buttonStyle(.plain)
        .listRowBackground(theme.surface)
        .accessibilityIdentifier("quran.library.surah.\(number)")
        // Offered only where a surah-info pack exists in this language: absent, never disabled.
        .swipeActions(edge: .trailing) {
            if viewModel.hasSurahInfo {
                infoButton(number).tint(theme.accent)
            }
        }
        .contextMenu {
            if viewModel.hasSurahInfo {
                infoButton(number)
            }
        }
    }

    private func infoButton(_ surah: Int) -> some View {
        Button {
            coordinator.showSurahInfo(surah)
        } label: {
            Label {
                Text(l10n.string(.quranSurahInfo))
            } icon: {
                Image(systemName: "info.circle")
            }
        }
        .accessibilityIdentifier("quran.library.surahInfo")
    }

    /// Not `ContentUnavailableView.search`: its words are the system's, and this app's are its own.
    @ViewBuilder
    private var emptyMessage: some View {
        if rows.isEmpty {
            ContentUnavailableView {
                Label {
                    Text(l10n.string(.quranNoSurahMatch))
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            }
            .accessibilityIdentifier("quran.library.empty")
        }
    }
}

/// The thirty juz.
struct QuranLibraryStartList: View {
    let rows: [QuranLibraryStartRow]
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator

    @Environment(\.theme) private var theme

    var body: some View {
        List {
            ForEach(rows) { row in
                Button {
                    viewModel.didOpen()
                    coordinator.open(row.target)
                } label: {
                    QuranLibraryStartRowView(row: row)
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.surface)
                .accessibilityIdentifier("quran.library.\(row.id)")
            }
        }
        .quranLibraryList()
    }
}

/// The sixty hizb, each disclosing its three later quarters.
struct QuranLibraryHizbList: View {
    let rows: [QuranLibraryHizbRow]
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator

    @Environment(\.theme) private var theme

    var body: some View {
        List {
            ForEach(rows) { row in
                hizbGroup(row)
            }
        }
        .quranLibraryList()
    }

    /// The label is a button to the hizb itself and the content is its quarters, each of which
    /// opens at its own ayah rather than at the hizb.
    private func hizbGroup(_ row: QuranLibraryHizbRow) -> some View {
        DisclosureGroup {
            ForEach(row.quarters) { quarter in
                Button {
                    viewModel.didOpen()
                    coordinator.open(quarter.target)
                } label: {
                    QuranLibraryStartRowView(row: quarter)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quran.library.\(quarter.id)")
            }
        } label: {
            Button {
                viewModel.didOpen()
                coordinator.open(row.hizb.target)
            } label: {
                QuranLibraryStartRowView(row: row.hizb)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quran.library.hizb.\(row.hizb.number)")
        }
        .listRowBackground(theme.surface)
    }
}

/// The printed pages as a grid of numbered cells, with the reader's current page marked and
/// brought to the middle.
struct QuranLibraryPageGrid: View {
    let cells: [QuranLibraryPageCell]
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator
    /// The page to mark as selected and to bring to the middle on appear.
    let currentPage: Int?

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                grid
                    .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .accessibilityIdentifier("quran.library.list")
            .onAppear {
                if let page = currentPage { proxy.scrollTo(page, anchor: .center) }
            }
        }
    }

    // The cells are the grid's direct children, so it stays lazy over all 604.
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(cells) { cell in
                Button {
                    viewModel.didOpen()
                    coordinator.open(.page(cell.number))
                } label: {
                    QuranLibraryPageCellView(cell: cell, isCurrent: cell.number == currentPage)
                }
                .buttonStyle(.plain)
                .id(cell.number)
                .accessibilityIdentifier("quran.library.page.\(cell.number)")
            }
        }
    }
}

// MARK: - Shared list chrome

private extension View {
    /// What the three lists have in common: plain style, the app's ground, and the column.
    func quranLibraryList() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .modifier(QuranLibraryColumn())
            .accessibilityIdentifier("quran.library.list")
    }
}

/// Holds a list's rows to a reading measure and centres them, while the scroll view itself stays
/// full width: a drag or a scroll wheel in the side margins still scrolls it, which a narrowed
/// `List` would not.
private struct QuranLibraryColumn: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .contentMargins(.horizontal, max(0, (width - AppBreakpoint.readingMeasure) / 2), for: .scrollContent)
    }
}
