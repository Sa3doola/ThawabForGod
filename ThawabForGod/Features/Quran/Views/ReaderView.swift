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
/// Still no translation: that slice is blocked on licensing rather than on code — see
/// `Resources/Corpus/README.md` — and it lands in this shape when it is not.
struct ReaderView: View {
    let viewModel: QuranViewModel
    let coordinator: QuranCoordinator
    let settings: ReaderSettings
    let reading: QuranReading
    /// Drives the tafsir sheet. Held here rather than built per row: one sheet is presented from
    /// this screen, so one view model answers for whichever verse it is showing.
    let tafsir: TafsirViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// Recomputed on each redraw rather than stored, which is what makes a change in the panel
    /// show through here: reading `settings.paper` inside `body` is the observation that brings
    /// this view back.
    private var style: ReadingStyle { settings.style(on: theme) }

    var body: some View {
        // `ScrollViewReader` so a bookmark and "continue reading" can land on the verse they
        // name rather than at the top of a 286-verse chapter.
        ScrollViewReader { proxy in
            ScrollView {
                // Lazy, unlike the eager `VStack` this replaces. Al-Baqara is 286 verses and a
                // juz can be more; building every one of them before the first frame was both a
                // visible pause on open and the reason `onAppear` could not be used to track
                // position — with an eager stack every row appears at once, so "the verse in
                // view" would have been the last verse of the chapter, immediately.
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    content
                }
                .padding(AppSpacing.xl)
                // The measure, and the one number on this screen that is a cap rather than a
                // proportion: a line of scripture the width of a Mac window loses the reader on
                // the way back from the end of it. See `AppBreakpoint.readingMeasure`.
                .frame(maxWidth: AppBreakpoint.readingMeasure)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .task(id: scrollTargetKey) { scroll(proxy) }
        }
        .background(background)
        .navigationTitle(title)
        .environment(\.readingStyle, style)
        .keepScreenAwake(settings.keepsScreenAwake)
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
        // **One modifier, three presentations.** The design asks for the commentary as a Mac
        // inspector pane, a 340-point trailing column on iPad and a medium sheet on iPhone —
        // which is exactly what `.inspector` already is: a trailing pane at regular width and a
        // sheet at compact. Writing that as a size-class branch over a sheet and an `HStack`
        // would be three layouts to keep in step, and the sheet would lose its detents on the
        // way. The detents below apply only in the case that becomes a sheet.
        .inspector(isPresented: isShowingTafsir) {
            tafsirPanel
                .inspectorColumnWidth(min: 320, ideal: 340, max: 420)
                .presentationDetents([.medium, .large])
        }
        .task { await viewModel.load(reading) }
        // On the way out rather than as they scroll — one save per sitting instead of one per
        // verse boundary. See `QuranViewModel.saveReadingPosition()`.
        .onDisappear { viewModel.saveReadingPosition() }
    }

    /// Puts the reader on the verse a bookmark named, once the verses exist to scroll to.
    ///
    /// Keyed on the target *and* the loaded phase, so it runs after the text arrives rather than
    /// against an empty `LazyVStack` — a `scrollTo` for a row that has not been built yet does
    /// nothing. Unanimated: this is where the reader asked to be, not a journey they want to
    /// watch the app take.
    private func scroll(_ proxy: ScrollViewProxy) {
        guard let target = coordinator.scrollTarget, case .ready = viewModel.readingPhase else {
            return
        }

        proxy.scrollTo(target, anchor: .top)
        coordinator.clearScrollTarget()
    }

    /// What re-runs the scroll: the verse being aimed at, and whether the text has loaded.
    private var scrollTargetKey: String {
        let isReady = if case .ready = viewModel.readingPhase { true } else { false }
        return "\(coordinator.scrollTarget?.description ?? "-")|\(isReady)"
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

    /// Two-way for the same reason: a swipe down and a Done button are one value changing.
    ///
    /// A `Bool` rather than the `VerseReference?` a sheet took, because that is what `.inspector`
    /// asks for — so the "cannot be up with nothing to show" guarantee moves from the modifier
    /// into `tafsirPanel`, which draws nothing at all when there is no verse.
    private var isShowingTafsir: Binding<Bool> {
        Binding(
            get: { coordinator.openTafsir != nil },
            set: { if !$0 { coordinator.closeTafsir() } }
        )
    }

    /// The commentary, or nothing. See `QuranCoordinator.openTafsir` — the reference is the
    /// presentation state, so there is no case where the panel is up without one.
    @ViewBuilder
    private var tafsirPanel: some View {
        if let reference = coordinator.openTafsir {
            TafsirPanel(
                viewModel: tafsir,
                reference: reference,
                surah: viewModel.surah(reference.surah),
                close: { coordinator.closeTafsir() }
            )
        }
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
            // One flat list, so the `LazyVStack` above is lazy in the rows rather than in the
            // chapters — see `QuranViewModel.Reading.Item`.
            ForEach(loaded.items) { item in
                row(item, in: loaded)
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.quranUnavailable))
        }
    }

    /// One row of the span: a chapter heading, a basmala, or a verse.
    @ViewBuilder
    private func row(
        _ item: QuranViewModel.Reading.Item,
        in loaded: QuranViewModel.Reading
    ) -> some View {
        switch item {
        case .heading(let number):
            if let surah = loaded.surahs[number] {
                chapterHeading(surah)
            }

        case .bismillah(let number):
            if let bismillah = loaded.surahs[number]?.bismillah {
                Text(bismillah)
                    .readingFont(size: style.typography.textSize)
                    .foregroundStyle(style.palette.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, AppLanguage.arabic.locale)
            }

        case .verse(let verse):
            VerseRow(
                verse: verse,
                isBookmarked: viewModel.isBookmarked(verse.id),
                showsNumber: settings.showsVerseNumbers,
                onSetBookmark: { isBookmarked in
                    Task { await viewModel.setBookmark(isBookmarked, for: verse.id) }
                },
                onShowTafsir: { coordinator.showTafsir(for: verse.id) }
            )
            // The scroll target, which is why it is the `VerseReference` and not the row's
            // position: a bookmark names a verse, not an index into a span.
            .id(verse.id)
            // Now that the rows are the lazy children, this fires as each one scrolls in —
            // which is what makes it a reading position rather than a constant.
            .onAppear { viewModel.noteVerseInView(verse.id) }
        }
    }

    /// Where one chapter ends and the next begins.
    ///
    /// A rule broken by the girih star, and the name centred under it — the mushaf's own way of
    /// marking a sura, and the one place in the reader the app's motif is drawn rather than
    /// implied. Centred rather than flush left because a heading that hangs off the same edge as
    /// the verses reads as another verse; a span that crosses a chapter boundary has to make that
    /// boundary unmistakable, since it is the only thing telling the reader the words changed
    /// book.
    ///
    /// The ornament is tinted from the *paper's* accent, not the app's: on parchment the app's
    /// amber washes out, which is the whole reason a named paper carries an accent of its own.
    private func chapterHeading(_ surah: Surah) -> some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                rule
                SurahHeaderView(surahName: l10n.language == .arabic ? surah.arabicName : surah.englishName)
//                GirihStar(inset: 3)
//                    .stroke(style.palette.accent, lineWidth: 1.4)
//                    .frame(width: 34, height: 34)
//                    .opacity(0.5)
                rule
            }
            .accessibilityHidden(true)
//
//            Text(surah.arabicName)
//                .appFont(.title3, weight: .semibold)
//                .foregroundStyle(style.palette.textPrimary)
//                .environment(\.locale, AppLanguage.arabic.locale)
//
//            Text(l10n.language == .arabic ? surah.transliteration : surah.englishName)
//                .appFont(.caption)
                .foregroundStyle(style.palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        // Extra breathing room above a new chapter, which the per-chapter stack used to give it
        // before the span was flattened.
        .padding(.top, AppSpacing.lg)
        .accessibilityElement(children: .combine)
    }

    private var rule: some View {
        Rectangle()
            .fill(style.palette.textSecondary.opacity(0.3))
            .frame(height: 1)
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
            viewModel: previewQuranViewModel(),
            coordinator: QuranCoordinator(),
            settings: ReaderSettings(settingsStore: settingsStore),
            reading: .surah(1),
            tafsir: previewTafsirViewModel()
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
