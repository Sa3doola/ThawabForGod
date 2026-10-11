//
//  QuranSearchView.swift
//  ThawabForGod
//

import SwiftUI

/// Search over the Arabic text and the installed translations: results appear while typing
/// (debounced by the view model), grouped by surah with counts, the matched words highlighted. A tap
/// opens the ayah, selected, in the reader's current mode.
///
/// **This view runs nothing.** `.task(id:)` hands the key to the view model, which sleeps, queries
/// and drops what went stale; here is only the drawing of its outcome. The list is drawn in the
/// reader's own palette, since it is made of the reader's own words, and the bars stay app chrome.
struct QuranSearchView: View {
    let viewModel: QuranSearchViewModel
    let coordinator: QuranCoordinator
    let settings: QuranReaderSettings

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    /// Presented on appear only when there is no text yet, so coming back to a result list does not
    /// raise the keyboard over it.
    @State private var isSearchPresented = false

    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = theme.reading(settings.resolvedTheme(systemColorScheme: colorScheme))
        content(palette)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(Text(l10n.string(.quranSearch)))
            .toolbarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.text, isPresented: $isSearchPresented, prompt: prompt)
            .searchScopes($viewModel.scope) {
                if viewModel.availableScopes.count > 1 {
                    ForEach(viewModel.availableScopes) { scope in
                        Text(l10n.string(scope.titleKey)).tag(scope)
                    }
                }
            }
            .autocorrectionDisabled()
            .task { await viewModel.prepare() }
            .task(id: viewModel.key) { await viewModel.run() }
            .onAppear { isSearchPresented = viewModel.text.isEmpty }
    }

    private var prompt: Text {
        switch viewModel.scope {
        case .quran: Text(l10n.string(.quranSearchPromptArabic))
        case .translations: Text(l10n.string(.quranSearchPromptTranslations))
        }
    }

    // MARK: States

    @ViewBuilder
    private func content(_ palette: ReadingPalette) -> some View {
        if let corpus = viewModel.corpus {
            switch viewModel.outcome {
            case .idle:
                ContentUnavailableView {
                    Label { Text(l10n.string(.quranSearchPrompt)) } icon: { Image(systemName: "magnifyingglass") }
                } description: {
                    Text(viewModel.availableScopes.count > 1
                        ? l10n.string(.quranSearchEmptyDescription)
                        : l10n.string(.quranSearchEmptyDescriptionArabic))
                }
            case .tooShort:
                ContentUnavailableView {
                    Label { Text(l10n.string(.quranSearchKeepTyping)) } icon: { Image(systemName: "character.cursor.ibeam") }
                } description: {
                    Text(l10n.string(.quranSearchTooShort))
                }
            case .failed:
                ContentUnavailableView {
                    Label { Text(l10n.string(.quranSearchFailed)) } icon: { Image(systemName: "exclamationmark.triangle") }
                }
            case .quran(let query, let exact, let attached, let count):
                if exact.isEmpty && attached.isEmpty {
                    noResults
                } else {
                    arabicList(query: query, exact: exact, attached: attached, count: count, corpus: corpus, palette: palette)
                }
            case .translations(let query, let groups, let count, let packs):
                if groups.isEmpty {
                    noResults
                } else {
                    translationList(query: query, groups: groups, count: count, packs: packs, corpus: corpus, palette: palette)
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Not `ContentUnavailableView.search`: that says "No results for …" in the system's words and
    /// would echo the query back without isolating it.
    private var noResults: some View {
        ContentUnavailableView {
            Label { Text(l10n.string(.quranSearchNoResults)) } icon: { Image(systemName: "magnifyingglass") }
        }
        .accessibilityIdentifier("quran.search.empty")
    }

    // MARK: Lists

    private func arabicList(
        query: QuranSearchQuery, exact: [SurahGroup<VerseReference>], attached: [SurahGroup<VerseReference>],
        count: Int, corpus: QuranCorpus, palette: ReadingPalette
    ) -> some View {
        List {
            countRow(count, palette: palette)
            arabicGroups(exact, query: query, corpus: corpus, palette: palette)
            if !attached.isEmpty {
                attachedHeader(attached.reduce(0) { $0 + $1.items.count }, palette: palette)
                arabicGroups(attached, query: query, corpus: corpus, palette: palette)
            }
        }
    }

    private func arabicGroups(
        _ groups: [SurahGroup<VerseReference>], query: QuranSearchQuery, corpus: QuranCorpus, palette: ReadingPalette
    ) -> some View {
        ForEach(groups) { group in
            Section {
                ForEach(group.items, id: \.self) { ref in
                    if let ayah = corpus.ayah(ref) {
                        resultButton(ref, palette: palette) {
                            QuranSearchArabicRow(
                                reference: reference(ref, corpus: corpus), text: ayah.text, query: query, palette: palette
                            )
                        }
                    }
                }
            } header: {
                groupHeader(group.surah, count: group.items.count, corpus: corpus, palette: palette)
            }
        }
    }

    private func translationList(
        query: QuranSearchQuery, groups: [SurahGroup<TranslationText>], count: Int, packs: [ContentPack],
        corpus: QuranCorpus, palette: ReadingPalette
    ) -> some View {
        List {
            countRow(count, palette: palette)
            ForEach(groups) { group in
                Section {
                    ForEach(group.items, id: \.self) { item in
                        resultButton(item.ayah, palette: palette) {
                            QuranSearchTranslationRow(
                                reference: reference(item.ayah, corpus: corpus), item: item,
                                pack: packs.first { $0.id == item.pack }, showsPack: packs.count > 1,
                                query: query, palette: palette
                            )
                        }
                    }
                } header: {
                    groupHeader(group.surah, count: group.items.count, corpus: corpus, palette: palette)
                }
            }
        }
    }

    // MARK: Pieces

    private func countRow(_ count: Int, palette: ReadingPalette) -> some View {
        Text(l10n.string(.quranSearchResultCount, l10n.string(count)))
            .appFont(.subheadline)
            .foregroundStyle(palette.secondaryText)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("quran.search.count")
    }

    /// Ranks the ayahs found only through a word with attached particles (للرحمن for الرحمن) after
    /// the exact matches.
    private func attachedHeader(_ count: Int, palette: ReadingPalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l10n.string(.quranSearchAttached, l10n.string(count)))
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(palette.text)
            Text(l10n.string(.quranSearchAttachedNote))
                .appFont(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(.top, AppSpacing.md)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("quran.search.attached")
    }

    private func groupHeader(_ surah: Int, count: Int, corpus: QuranCorpus, palette: ReadingPalette) -> some View {
        HStack {
            Text(verbatim: "\(l10n.string(surah, grouped: false)). \(corpus.surah(surah)?.name(in: l10n.language) ?? "")")
            Spacer()
            Text(l10n.string(count))
        }
        .foregroundStyle(palette.secondaryText)
    }

    private func resultButton(
        _ ref: VerseReference, palette: ReadingPalette, @ViewBuilder label: () -> some View
    ) -> some View {
        Button {
            coordinator.open(.ayah(ref))
        } label: {
            label()
        }
        .tint(palette.text)
        .listRowBackground(palette.background)
    }

    /// One string, so the colon between the numbers cannot be reordered around them.
    private func reference(_ ref: VerseReference, corpus: QuranCorpus) -> String {
        let numbers = "\(l10n.string(ref.surah, grouped: false)):\(l10n.string(ref.verse, grouped: false))"
        return "\(corpus.surah(ref.surah)?.name(in: l10n.language) ?? "") \(numbers)"
    }
}
