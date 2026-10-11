//
//  TranslationTextView.swift
//  ThawabForGod
//

import SwiftUI

/// One translation of one ayah: the text in its own direction (the reader is forced right-to-left),
/// tappable footnote numbers, and the pack's name beneath. Ported from Mushaf.
///
/// `fontSize` is in points and already scaled for Dynamic Type by the caller.
struct TranslationTextView: View {
    let item: AyahPanelTranslation
    let fontSize: CGFloat

    @State private var openFootnote: Footnote?
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.readingPalette) private var palette

    private struct Footnote: Identifiable {
        let number: Int
        let id: String
        let note: String
    }

    var body: some View {
        let document = item.document
        VStack(alignment: .leading, spacing: 4) {
            Text(document.attributedString(fontSize: fontSize, markerColor: palette.ornament) { l10n.string($0, grouped: false) })
                .font(QuranFaces.chromeFont(size: fontSize, weight: .regular))
                .foregroundStyle(palette.text)
                .lineSpacing(fontSize * 0.2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                // Footnote markers are `footnote://ID` links: show the note, never leave the app.
                .environment(\.openURL, OpenURLAction { url in
                    guard let id = TranslationDocument.footnoteID(from: url),
                          let footnote = document.footnotes.first(where: { $0.id == id }) else { return .discarded }
                    openFootnote = Footnote(number: footnote.number, id: footnote.id, note: footnote.note)
                    return .handled
                })
                .popover(item: $openFootnote) { footnote in
                    FootnoteNote(number: footnote.number, note: footnote.note, direction: item.pack.direction)
                        .presentationDetents([.medium])
                }
            Text(verbatim: item.pack.name(in: l10n.language))
                .appFont(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .environment(\.layoutDirection, item.pack.direction.isRightToLeft ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: document.plainText))
        .accessibilityHint(Text(verbatim: item.pack.name(in: l10n.language)))
        .accessibilityActions {
            ForEach(document.footnotes, id: \.id) { footnote in
                Button {
                    openFootnote = Footnote(number: footnote.number, id: footnote.id, note: footnote.note)
                } label: {
                    Text(l10n.string(.quranPanelFootnote, l10n.string(footnote.number, grouped: false)))
                }
            }
        }
    }
}

/// A footnote's text: a popover on iPad and Mac, a sheet on a compact iPhone.
private struct FootnoteNote: View {
    let number: Int
    let note: String
    let direction: TextDirection

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.readingPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.string(.quranPanelFootnote, l10n.string(number, grouped: false)))
                    .appFont(.headline)
                Text(verbatim: note)
                    .appFont(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        .frame(idealWidth: 360, maxWidth: 420)
        .foregroundStyle(palette.text)
        .background(palette.background)
        .environment(\.layoutDirection, direction.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
