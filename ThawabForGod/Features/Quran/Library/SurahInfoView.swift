//
//  SurahInfoView.swift
//  ThawabForGod
//

import SwiftUI

/// A surah's introduction: its facts (revelation place, ayahs, pages, juz) and the surah-info
/// pack's text in the interface language, drawn with the tafsir HTML renderer.
///
/// Ported from Mushaf's sheet, but a pushed screen here (design note 4.2): it ends by going back,
/// so there is no Done button. An app screen like the Library rather than a page, so it is drawn
/// in the app's colours.
struct SurahInfoView: View {
    let viewModel: SurahInfoViewModel
    let surah: Int

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    /// Mushaf's 17, scaled with Dynamic Type here and handed down as an already-scaled size.
    @ScaledMetric(relativeTo: .body) private var textSize: CGFloat = 17

    var body: some View {
        ScrollView {
            column
                .padding()
                .frame(maxWidth: AppBreakpoint.readingMeasure, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(verbatim: viewModel.facts(for: surah)?.surah.name(in: l10n.language) ?? ""))
        .toolbarTitleDisplayMode(.inline)
        .task(id: surah) {
            // `prepare` is idempotent; a route can arrive before the Library has asked.
            await viewModel.prepare(language: l10n.language)
            await viewModel.load(surah: surah)
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let facts = viewModel.facts(for: surah) {
                SurahInfoFactsCard(facts: facts)
            }
            introduction
        }
    }

    @ViewBuilder
    private var introduction: some View {
        // Never `viewModel.phase` directly: it may be about another surah (see `phase(for:)`).
        switch viewModel.phase(for: surah) {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .loaded(let content):
            TafsirTextView(
                document: content.document, direction: content.pack.direction, fontSize: textSize,
                textColor: theme.textPrimary, headingColor: theme.accent
            )
            // On the text alone, in a vertical scroll view, as Mushaf had it (design note 3.6).
            .textSelection(.enabled)
            .accessibilityIdentifier("quran.surahInfo.text")
            Text(verbatim: attribution(content.pack))
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        case .missing:
            Text(l10n.string(.quranSurahInfoUnavailable))
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
        }
    }

    /// The pack's name and author, as one verbatim line: both are the pack's own words.
    private func attribution(_ pack: ContentPack) -> String {
        "\(pack.name(in: l10n.language)) · \(pack.author(in: l10n.language))"
    }
}

/// The surah's name and its four facts, on a surface card.
private struct SurahInfoFactsCard: View {
    let facts: SurahInfoFacts

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SurahNameGlyph(surah: facts.surah, name: facts.surah.arabicName, size: 44)
                .foregroundStyle(theme.textPrimary)
                .accessibilityHidden(true)
            Grid(alignment: .leading, horizontalSpacing: AppSpacing.lg, verticalSpacing: AppSpacing.xs) {
                row(l10n.string(.quranSurahInfoRevelation), value: revelationPlace)
                row(l10n.string(.quranSurahInfoAyahs), value: number(facts.surah.ayahCount))
                if let pages = facts.pages {
                    row(l10n.string(.quranSurahInfoPages), value: pageRange(pages))
                }
                row(l10n.string(.quranSurahInfoStartsIn), value: l10n.string(.quranJuzNumber, number(facts.startJuz)))
            }
            .appFont(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: AppRadius.md))
        .accessibilityIdentifier("quran.surahInfo.facts")
    }

    private func row(_ title: String, value: String) -> some View {
        GridRow {
            Text(verbatim: title).foregroundStyle(theme.textSecondary)
            Text(verbatim: value).foregroundStyle(theme.textPrimary)
        }
    }

    private var revelationPlace: String {
        switch facts.surah.revelationPlace {
        case .makkah: l10n.string(.quranMeccan)
        case .madinah: l10n.string(.quranMedinan)
        }
    }

    private func number(_ value: Int) -> String {
        l10n.string(value, grouped: false)
    }

    /// `start–last`, or one number when the surah sits on a single page. Arabic-Indic digits are
    /// Arabic numbers to the bidi algorithm, so in left-to-right text the dash gets left-to-right
    /// marks (the same rule `TafsirEntry.rangeText` follows); right-to-left keeps the natural order.
    private func pageRange(_ pages: ClosedRange<Int>) -> String {
        guard pages.lowerBound != pages.upperBound else { return number(pages.lowerBound) }
        let dash = layoutDirection == .rightToLeft ? "–" : "\u{200E}–\u{200E}"
        return "\(number(pages.lowerBound))\(dash)\(number(pages.upperBound))"
    }
}
