//
//  ReaderView.swift
//  ThawabForGod
//

import SwiftUI

/// The reading surface: one chapter, or one part.
///
/// Deliberately the same screen for both. A part is a span of verses that happens to cross
/// chapter boundaries, and giving it a screen of its own would mean two places to change when
/// the reader gains a translation, a bookmark or a font control.
///
/// Minimal on purpose — Arabic text, one theme, no translation. The customization panel, the
/// translations and the bookmarks are the slices that come after this one; what this establishes
/// is the shape they land in.
struct ReaderView: View {
    let viewModel: QuranViewModel
    let reading: QuranReading

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(title)
        .task { await viewModel.load(reading) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.readingPhase {
        case .loading:
            ProgressView(l10n.string(.quranTitle))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)

        case .ready(let loaded):
            ForEach(loaded.surahOrder, id: \.self) { number in
                chapter(number, in: loaded)
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.quranUnavailable))
        }
    }

    /// One chapter's worth of this span: its heading where it needs one, then its verses.
    @ViewBuilder
    private func chapter(_ number: Int, in loaded: QuranViewModel.Reading) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Named only when the span covers more than one chapter. Reading a single chapter,
            // the navigation title already says which — a heading under it would be the name
            // twice on one screen.
            if loaded.surahOrder.count > 1, let surah = loaded.surahs[number] {
                chapterHeading(surah)
            }

            if loaded.showsBismillah(forSurah: number), let bismillah = loaded.surahs[number]?.bismillah {
                Text(bismillah)
                    .appFont(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, AppLanguage.arabic.locale)
            }

            ForEach(loaded.verses(inSurah: number)) { verse in
                VerseRow(verse: verse)
            }
        }
    }

    private func chapterHeading(_ surah: Surah) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(surah.arabicName)
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)
                .environment(\.locale, AppLanguage.arabic.locale)

            Text(l10n.language == .arabic ? surah.transliteration : surah.englishName)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    /// The chapter's Arabic name, or the part's number.
    ///
    /// Read off the loaded text rather than fetched separately, which means it is empty for the
    /// moment before the verses arrive — a title that appears with its content rather than a
    /// second load to put a word on screen a beat earlier.
    private var title: String {
        switch reading {
        case .surah(let number):
            guard case .ready(let loaded) = viewModel.readingPhase else { return "" }
            return loaded.surahs[number]?.arabicName ?? ""

        case .juz(let number):
            return "\(l10n.string(.quranJuzLabel)) \(l10n.string(number, grouped: false))"
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        ReaderView(
            viewModel: QuranViewModel(
                useCase: GetQuranUseCase(
                    repository: QuranRepository(database: CorpusDatabase(name: "quran"))
                )
            ),
            reading: .surah(1)
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
