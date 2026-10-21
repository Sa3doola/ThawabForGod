//
//  QuranReaderSettingsSheet.swift
//  ThawabForGod
//

import SwiftUI

/// A page the sheet pushes. Local to the sheet: the tab's path never sees it.
enum QuranSettingsPage: Hashable {
    case packs
    case sources
}

/// The reader's settings as a sheet. It opens at medium height with the page still live behind it
/// (`presentationBackgroundInteraction`), so the reader's own page is the preview: the panel has
/// none of its own.
struct QuranReaderSettingsSheet: View {
    let viewModel: QuranSettingsViewModel
    let about: AboutViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationManager.self) private var l10n
    @State private var page: [QuranSettingsPage] = []

    var body: some View {
        NavigationStack(path: $page) {
            QuranSettingsForm(
                viewModel: viewModel,
                onShowPacks: { page.append(.packs) },
                onShowSources: { page.append(.sources) }
            )
            .navigationTitle(l10n.string(.readerOptionsTitle))
            .toolbarTitleDisplayMode(.inline)
            .quranSettingsPinnedHeader(title: l10n.string(.readerOptionsTitle), done: l10n.string(.readerDone)) { dismiss() }
            .navigationDestination(for: QuranSettingsPage.self) { page in
                switch page {
                case .packs: ContentPacksView(viewModel: viewModel)
                case .sources: SourcesView(viewModel: about)
                }
            }
        }
        .task { await viewModel.load() }
        .quranSettingsSheetFrame()
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
