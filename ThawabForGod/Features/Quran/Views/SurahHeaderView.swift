//
//  SurahHeaderView.swift
//  ThawabForGod
//

import SwiftUI

/// A chapter's calligraphic "سورة …" title, as one glyph of the "Quran karim 114" face.
///
/// The shared piece: `SurahHeaderView` frames it at the top of a chapter, and anything else that
/// wants the drawn name rather than the typed one uses this directly, so there is one place that
/// knows the glyph is a `Text(verbatim:)` and that VoiceOver must be told what it says.
struct SurahNameGlyphView: View {
    let surah: Int
    /// Final, in points — callers that follow Dynamic Type scale it themselves.
    let size: Double
    /// Read aloud in place of the glyph. Without it VoiceOver announces the character the glyph
    /// happens to sit on — "exclamation mark" for Al-Fatiha.
    let accessibilityName: String

    var body: some View {
        // Verbatim, never a `LocalizedStringKey`: `"!"` looked up in the String Catalog is a key
        // somebody might one day translate.
        Text(verbatim: SurahNameGlyph.glyph(forSurah: surah))
            .font(.custom(SurahNameGlyph.postScriptName, fixedSize: size))
            .lineLimit(1)
            .accessibilityLabel(accessibilityName)
    }
}

/// Where one chapter ends and the next begins.
///
/// The drawn title inside a double rule, centred — the mushaf's own way of marking a sura. Centred
/// rather than flush because a heading that hangs off the same edge as the verses reads as another
/// verse; a span that crosses a chapter boundary has to make that boundary unmistakable.
///
/// Tinted from the *paper's* accent rather than the app's, because on parchment the app's amber
/// washes out — the reason a named paper carries an accent of its own.
struct SurahHeaderView: View {
    let surah: Surah

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.readingStyle) private var style
    /// The multiplier the verses are scaled by, so the heading keeps its proportion to them at
    /// every Dynamic Type size.
    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1.5
    /// The heading's size as a share of the verse's — large enough to read as a title from across
    /// the page, small enough that the longest names fit a phone's measure without shrinking.
    static let scale: Double = 3

    var body: some View {
        SurahNameGlyphView(
            surah: surah.id,
            size: style.typography.textSize * Double(typeScale) * Self.scale,
            accessibilityName: l10n.language == .arabic ? surah.arabicName : surah.englishName
        )
        .foregroundStyle(style.palette.textPrimary)
        // The glyph is wide and short; this keeps a long name from touching the frame.
        .minimumScaleFactor(0.5)
//        .padding(.horizontal, AppSpacing.lg)
//        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background { frame }
        .accessibilityAddTraits(.isHeader)
    }

    /// Two rules, the inner one lighter — a printed cartouche reduced to what reads at any size
    /// and costs no image asset that would need a colour of its own per paper.
    private var frame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(style.palette.accent, lineWidth: 1.5)
            RoundedRectangle(cornerRadius: AppRadius.md - 3)
                .strokeBorder(style.palette.accent.opacity(0.45), lineWidth: 1)
                .padding(4)
        }
        .background(style.palette.accent.opacity(0.06), in: .rect(cornerRadius: AppRadius.md))
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()
    FontRegistrar.registerBundledFonts()

    return VStack(spacing: 24) {
        ForEach([1, 2, 9, 33, 114], id: \.self) { number in
            SurahHeaderView(surah: Surah(
                id: number,
                arabicName: "—",
                transliteration: "—",
                englishName: "Surah \(number)",
                verseCount: 1,
                revelationPlace: .meccan,
                revelationOrder: 1,
                bismillah: nil
            ))
        }
    }
    .padding()
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
