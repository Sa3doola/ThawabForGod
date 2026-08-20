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
/// The reader's own look is resolved here and put into the environment once, rather than handed
/// down through `chapter(_:in:)` to `VerseRow` — the row is three levels below this and the panel
/// that edits the value is presented from the top, so the environment is what lets the value reach
/// the leaf without every view in between naming it.
///
/// Still no translation and no bookmark: those are the slices after this one, and they land in
/// this shape.
struct ReaderView: View {
    let viewModel: QuranViewModel
    let coordinator: QuranCoordinator
    let settings: ReaderSettings
    let reading: QuranReading

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// Recomputed on each redraw rather than stored, which is what makes a change in the panel
    /// show through here: reading `settings.paper` inside `body` is the observation that brings
    /// this view back.
    private var style: ReadingStyle { settings.style(on: theme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(background)
        .navigationTitle(title)
        .environment(\.readingStyle, style)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    coordinator.customize()
                } label: {
                    Label(l10n.string(.readerOptionsTitle), systemImage: "textformat.size")
                }
            }
        }
        .sheet(isPresented: isCustomizing) {
            ReaderSettingsSheet(settings: settings, coordinator: coordinator)
        }
        .task { await viewModel.load(reading) }
    }

    /// The chosen paper, but only under text that is actually there.
    ///
    /// The loading and unavailable states draw themselves in `Theme`'s colours, and those are
    /// picked against `Theme`'s background — an `InlineNotice` in the app's light-on-dark text
    /// sitting on parchment would be the one unreadable screen in the feature. The paper is for
    /// the page; a spinner is not the page.
    private var background: Color {
        if case .ready = viewModel.readingPhase {
            style.palette.background
        } else {
            theme.background
        }
    }

    /// Two-way, as the reading destination is: dragging the sheet down writes `false` back and
    /// the coordinator follows, so a dismiss by gesture and one by the Done button are the same
    /// value changing.
    private var isCustomizing: Binding<Bool> {
        Binding(
            get: { coordinator.isCustomizing },
            set: { if !$0 { coordinator.finishCustomizing() } }
        )
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
                    .readingFont(size: style.typography.textSize)
                    .foregroundStyle(style.palette.accent)
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
                .foregroundStyle(style.palette.textPrimary)
                .environment(\.locale, AppLanguage.arabic.locale)

            Text(l10n.language == .arabic ? surah.transliteration : surah.englishName)
                .appFont(.caption)
                .foregroundStyle(style.palette.textSecondary)
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
            coordinator: QuranCoordinator(),
            settings: ReaderSettings(settingsStore: settingsStore),
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
