//
//  SeparatedAyahRow.swift
//  ThawabForGod
//

import SwiftUI

/// One ayah: its words in the reader's face and size, then its end-of-ayah marker, then every
/// installed translation under it.
///
/// The translations sit **beside the Arabic, not inside its tap target**, so a footnote number takes
/// its own tap rather than opening the panel.
struct SeparatedAyahRow: View {
    let ayah: Ayah
    let surahName: String
    let textSize: Double
    let translations: [AyahPanelTranslation]
    let isSelected: Bool
    var highlight: HighlightColor?
    let onTap: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.readingPalette) private var palette
    @Environment(\.quranFaces) private var faces
    @Environment(\.readingStyle) private var style
    /// The multiplier `readingFont(size:)` applies to the words, so the marker and the fallback
    /// stretches — whose faces are named inside the attributed string, where that modifier cannot
    /// reach — grow with them. The translations' size takes it too.
    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            Text(paragraph)
                .readingFont(size: textSize)
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(highlight.map { palette.highlight($0) } ?? .clear, in: .rect(cornerRadius: 8))
                .background(isSelected ? palette.selection : .clear, in: .rect(cornerRadius: 8))
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
            ForEach(translations) { item in
                TranslationTextView(item: item, fontSize: max(14, textSize * 0.6) * typeScale)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 14)
            }
            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
        }
        // One VoiceOver element per ayah: the reference, then the Arabic, then each translation.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(l10n.string(.quranSurahAyah, surahName, l10n.string(ayah.id.verse, grouped: false))))
        .accessibilityValue(Text(verbatim: ([ayah.text] + translations.map(\.document.plainText)).joined(separator: "\n")))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, onTap)
    }

    /// The words, a no-break space, then the marker — one paragraph, so the marker wraps with its
    /// ayah and a line never starts with a lone number.
    ///
    /// **The marker is always KFGQPC Hafs, whichever face the words are in.** The marker's text is
    /// the ayah number in Arabic-Indic digits, which Hafs draws as one ornamented end-of-ayah glyph;
    /// Amiri would draw three bare digits. The words carry no font of their own and take the reader's
    /// face from `readingFont(size:)`, except the few stretches KFGQPC Hafs cannot draw (the
    /// silent-letter mark of the public text), which `QuranAyahText` names as Amiri Quran. The
    /// characters are the stored ones either way; only the marker and those stretches name a face.
    private var paragraph: AttributedString {
        let scaledSize = textSize * Double(typeScale)
        var text = QuranAyahText.attributed(
            ayah.text,
            face: style.font,
            scaledSize: scaledSize,
            hafsIsRegistered: faces.contains(.ayahText)
        )
        guard !ayah.marker.isEmpty else { return text }
        var marker = AttributedString(ayah.marker)
        marker.font = faces.contains(.ayahText)
            ? ReaderFont.kfgqpcHafs.font(size: scaledSize)
            : nil
        text.append(AttributedString("\u{00A0}"))
        text.append(marker)
        return text
    }
}
