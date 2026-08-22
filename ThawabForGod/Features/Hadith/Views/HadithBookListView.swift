//
//  HadithBookListView.swift
//  ThawabForGod
//

import SwiftUI

/// The kitab one collection is divided into — 97 of them in Bukhari, 57 in Muslim.
///
/// Loaded on `.task(id:)` keyed on the collection rather than on `.task`, so that opening a
/// second collection reloads instead of showing the first one's divisions under the second one's
/// title. The view model holds a single slot for this list, which is what makes that key matter.
struct HadithBookListView: View {
    let viewModel: HadithViewModel
    let coordinator: HadithCoordinator
    let collection: HadithCollection

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                content
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(collection.arabicName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: collection.id) { await viewModel.loadBooks(in: collection.id) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.books {
        case .loading:
            ProgressView(l10n.string(.hadithLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready(let books):
            ForEach(books) { book in
                HadithBookRow(book: book) {
                    coordinator.open(book.id)
                }
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.hadithUnavailable))
        }
    }
}
