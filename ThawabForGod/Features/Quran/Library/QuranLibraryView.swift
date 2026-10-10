//
//  QuranLibraryView.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran tab's root. In M5.1 the surah index alone; M5.2 grows this same type into the Library
/// (surah, juz, hizb and page lists, the go-to field, Continue reading).
///
/// It reads what the view model has loaded and nothing else: the 114 rows come from the corpus the
/// reader will draw, so a row can never name a surah the reader cannot open. A row asks the
/// coordinator for the reader at that surah and has no resume affordance yet — after going back, a
/// row opens its surah at the top, because "continue reading" is M5.2's row and M6's persistence.
///
/// App colours and type, not the page palette: this is an app screen, and the reader's paper is
/// something the bars take on only while the reader itself is in front.
struct QuranLibraryView: View {
    let viewModel: QuranReaderViewModel
    let coordinator: QuranCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .navigationTitle(l10n.string(.quranTitle))
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
        case .failed:
            QuranLoadFailureView { await viewModel.retry() }
        case .ready(let corpus):
            List(corpus.surahs) { surah in
                QuranSurahRow(surah: surah) { coordinator.open(.surah(surah.number)) }
                    .listRowBackground(theme.surface)
                    .accessibilityIdentifier("quran.library.surah.\(surah.number)")
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("quran.library.list")
        }
    }
}

/// One surah: its number, its name in the interface language, and the Arabic name beside it when
/// the interface is not already Arabic.
private struct QuranSurahRow: View {
    let surah: Surah
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(l10n.string(surah.number))
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .frame(minWidth: 32)
                Text(verbatim: surah.name(in: l10n.language))
                    .appFont(.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 8)
                if l10n.language != .arabic {
                    Text(verbatim: surah.arabicName)
                        .appFont(.body)
                        .foregroundStyle(theme.textSecondary)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
