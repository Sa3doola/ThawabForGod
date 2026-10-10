//
//  SeparatedReaderView.swift
//  ThawabForGod
//

import SwiftUI

/// A request to scroll to an ayah of the surah on screen. `serial` makes two requests for the
/// same ayah different values.
nonisolated struct SeparatedScrollRequest: Equatable, Sendable {
    let ayah: VerseReference
    let serial: Int
}

/// One surah as a vertical list of ayahs, at the reader's own size and face — the separated mode,
/// and the whole Quran reader in a build without the printed pages.
///
/// Ported from Mushaf's `SeparatedReaderView`, rendering only: the translations under each ayah,
/// the context menu and the panel arrive with the screens (M5), the bookmark and note marks with
/// the user data (M6). Two of Noor's lessons are kept from its own reader: the header, the basmala
/// and every row are **siblings** in the `LazyVStack` — a stack is lazy only in its direct
/// children, and nesting a surah in one child built all 286 rows of Al-Baqara before the first
/// frame — and the position is reported as it changes rather than written on the way out.
struct SeparatedReaderView: View {
    let surah: Surah
    let ayahs: ArraySlice<Ayah>
    let basmala: String
    let selectedAyah: VerseReference?
    var marks: QuranAyahMarks = .none
    /// The ayah to open at, read once when the view appears; `nil` opens at the top.
    var initialAyah: VerseReference?
    /// A jump to an ayah of this surah while it is on screen. Not read at creation: a list being
    /// created is positioned by `initialAyah`.
    var scrollRequest: SeparatedScrollRequest? = nil
    let onSelect: (VerseReference) -> Void
    /// The ayah now at the top of the viewport, as the reader scrolls.
    var onTopAyahChange: (VerseReference) -> Void = { _ in }

    @Environment(LocalizationManager.self) private var l10n
    @Environment(QuranReaderSettings.self) private var settings
    @Environment(\.readingPalette) private var palette

    /// Ayah at the top of the viewport.
    @State private var topAyah: VerseReference?

    /// Widest the surah header gets on iPad and the Mac.
    private static let headerMaxWidth: CGFloat = 560

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    SeparatedSurahBanner(surah: surah, name: surah.name(in: l10n.language))
                        .frame(maxWidth: Self.headerMaxWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    if surah.hasBasmalaLine {
                        Text(verbatim: basmala)
                            .readingFont(size: settings.textSize)
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    ForEach(ayahs) { ayah in
                        SeparatedAyahRow(
                            ayah: ayah,
                            surahName: surah.name(in: l10n.language),
                            textSize: settings.textSize,
                            isSelected: selectedAyah == ayah.id,
                            highlight: marks.highlight(ayah.id)
                        ) {
                            onSelect(ayah.id)
                        }
                        .id(ayah.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal)
            }
            .scrollPosition(id: $topAyah, anchor: .top)
            .task {
                // Jump to the requested ayah once; `scrollTo` also reaches rows the lazy stack has
                // not built yet (`scrollPosition(id:)` ignores its initial value).
                guard topAyah == nil, let initialAyah, initialAyah.verse > 1 else { return }
                await Task.yield()
                proxy.scrollTo(initialAyah, anchor: .top)
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request, request.ayah.surah == surah.number else { return }
                proxy.scrollTo(request.ayah, anchor: .top)
            }
        }
        // Quran text is right-to-left whatever the interface language.
        .environment(\.layoutDirection, .rightToLeft)
        .background(palette.background)
        .onChange(of: topAyah) { _, ayah in
            if let ayah { onTopAyahChange(ayah) }
        }
    }
}

/// The printed surah header over a surah in separated mode: the same glyph as on a Mushaf page, as
/// wide as the column up to a readable maximum.
private struct SeparatedSurahBanner: View {
    let surah: Surah
    let name: String

    var body: some View {
        Color.clear
            .aspectRatio(MushafPageMetrics.headerAdvanceEm / MushafPageMetrics.headerHeightEm, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    SurahHeaderGlyph(surah: surah, name: name, fontSize: geometry.size.width / MushafPageMetrics.headerAdvanceEm)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One ayah: its words in the reader's face and size, then its end-of-ayah marker.
private struct SeparatedAyahRow: View {
    let ayah: Ayah
    let surahName: String
    let textSize: Double
    let isSelected: Bool
    var highlight: HighlightColor?
    let onTap: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.readingPalette) private var palette
    @Environment(\.quranFaces) private var faces
    @Environment(\.readingStyle) private var style
    /// The multiplier `readingFont(size:)` applies to the words, so the marker and the fallback
    /// stretches — whose faces are named inside the attributed string, where that modifier cannot
    /// reach — grow with them.
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
            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
        }
        // One VoiceOver element per ayah: the reference, then the Arabic.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(l10n.string(.quranSurahAyah, surahName, l10n.string(ayah.id.verse, grouped: false))))
        .accessibilityValue(Text(verbatim: ayah.text))
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
