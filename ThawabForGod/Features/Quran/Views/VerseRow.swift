//
//  VerseRow.swift
//  ThawabForGod
//

import SwiftUI

/// One verse, as it is read.
///
/// The number is set *inside the text* between ornate parentheses — `﴿٢٥٥﴾` — rather than beside
/// it in a badge, because that is where the mushaf puts it and because a marker that flows with
/// the paragraph keeps its place when the text wraps. `Text` concatenation is what makes that a
/// single laid-out paragraph rather than two views that only look like one.
struct VerseRow: View {
    let verse: Verse
    let isBookmarked: Bool
    /// Whether to set the ayah marker after the words. `true` everywhere the reader has not said
    /// otherwise — see `ReaderSettings.showsVerseNumbers`.
    var showsNumber = true
    let onSetBookmark: (Bool) -> Void
    /// Opens the commentary on this verse. Optional so the row still draws everywhere it is
    /// reused without a tafsir to reach for — a preview, or a screen that has no sheet to put it
    /// in.
    var onShowTafsir: (() -> Void)?

    @Environment(LocalizationManager.self) private var l10n
    /// The reader's paper and type metrics, resolved once by `ReaderView`. `fallback` outside it —
    /// the app's colours at the app's size — so this row still draws correctly in a preview or
    /// anywhere else it is reused.
    @Environment(\.readingStyle) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            text

            HStack(spacing: 12) {
                bookmarkButton

                if onShowTafsir != nil {
                    tafsirButton
                }

                if let sajda = verse.sajda {
                    sajdaMarker(sajda)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Forced right-to-left rather than left to inherit the screen's direction — the same
        // reasoning as `DhikrCard`. The verse is Arabic whatever the interface language is, and
        // an English reader's left-aligned paragraph would hang from the wrong edge. The bidi
        // algorithm orders the *characters* correctly but has nothing to say about that.
        .environment(\.layoutDirection, .rightToLeft)
        // So VoiceOver reads it in Arabic rather than in the interface's voice.
        .environment(\.locale, AppLanguage.arabic.locale)
        // `.contain` rather than `.combine`: combining would fold the bookmark button into the
        // verse's own label and leave VoiceOver with no way to reach it. The text below carries
        // the label; the button stays a separate, reachable element inside this group.
        .accessibilityElement(children: .contain)
    }

    private var text: some View {
        // Concatenated `Text` rather than an `HStack`, so the marker is part of the paragraph and
        // wraps with it — which is what a mushaf does and what a separate view could not. The
        // accessibility label names the verse either way, so hiding the marker takes nothing away
        // from a reader using VoiceOver.
        (showsNumber
            ? Text(verse.text)
                + Text(verbatim: " ﴿")
                + Text(l10n.string(verse.number, grouped: false))
                + Text(verbatim: "﴾")
            : Text(verse.text))
        .readingFont(size: style.typography.textSize)
        .foregroundStyle(style.palette.textPrimary)
        .lineSpacing(style.typography.lineSpacing)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Keeps or forgets this verse.
    ///
    /// Drawn on every verse rather than hidden behind a long press, because an affordance nobody
    /// can see is one nobody uses — and outlined-when-unset keeps it quiet enough to live under
    /// 286 verses without competing with them. The symbol is the state; there is no label, which
    /// is also what keeps it out of the way of the Arabic.
    private var bookmarkButton: some View {
        Button {
            onSetBookmark(!isBookmarked)
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .appFont(.footnote, weight: .medium)
                .foregroundStyle(isBookmarked ? style.palette.accent : style.palette.textSecondary)
                // A fixed box, so filling the symbol does not nudge the sajda mark beside it.
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        // Drawn at 22 and tapped at 44 — see `minimumTapTarget()`. The glyph has to stay small
        // to live quietly under 286 verses; the fingertip aiming at it does not shrink to match.
        .minimumTapTarget()
        .accessibilityLabel(l10n.string(isBookmarked ? .quranBookmarkRemove : .quranBookmarkAdd))
        .accessibilityAddTraits(isBookmarked ? [.isButton, .isSelected] : .isButton)
    }

    /// Opens what the commentary says about this verse.
    ///
    /// Beside the bookmark and drawn the same way — quiet, symbol-only, no label — for the same
    /// reason: it sits under every one of Al-Baqara's 286 verses and must not compete with them.
    @ViewBuilder
    private var tafsirButton: some View {
        if let onShowTafsir {
            Button(action: onShowTafsir) {
                Image(systemName: "text.book.closed")
                    .appFont(.footnote, weight: .medium)
                    .foregroundStyle(style.palette.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel(l10n.string(.tafsirOpen))
        }
    }

    /// The place-of-prostration mark, and the word for it.
    ///
    /// Both kinds are drawn the same way. Which of them obliges a prostration is a question the
    /// schools answer differently, and the corpus keeps them apart precisely so that a later
    /// slice can act on the difference rather than have it already flattened here.
    private func sajdaMarker(_ sajda: Sajda) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "۩")
            Text(l10n.string(.quranSajda))
        }
        .appFont(.caption, weight: .medium)
        .foregroundStyle(style.palette.accent)
    }

    /// Spoken as "verse 255", then the verse — so the reference comes before the recitation
    /// rather than trailing it as the ornate parentheses would have VoiceOver do.
    private var accessibilityLabel: String {
        "\(l10n.string(.quranVerseLabel)) \(l10n.string(verse.number, grouped: false)). \(verse.text)"
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VerseRow(
        verse: Verse(
            id: VerseReference(surah: 2, verse: 255),
            text: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            juz: 3,
            hizb: 5,
            rubElHizb: 17,
            page: 42,
            sajda: nil
        ),
        isBookmarked: true,
        onSetBookmark: { _ in }
    )
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
