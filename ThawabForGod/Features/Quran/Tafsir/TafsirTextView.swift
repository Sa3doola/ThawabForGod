//
//  TafsirTextView.swift
//  ThawabForGod
//

import SwiftUI

/// A tafsir entry's text: one `Text` per block, so VoiceOver reads it as normal text and finds the
/// headings with the rotor. The pack's direction is set on the view (the reader itself is forced
/// right-to-left); an all-Arabic block inside an English tafsir reads right-to-left on its own.
///
/// The two colours are parameters because the caller knows whether it sits on an app screen or on
/// a page, and `.textSelection` is deliberately not applied here for the same reason: the caller
/// decides.
struct TafsirTextView: View {
    let document: TafsirDocument
    /// The pack's direction.
    let direction: TextDirection
    /// Points, already scaled for Dynamic Type.
    let fontSize: CGFloat
    let textColor: Color
    let headingColor: Color

    @Environment(\.quranFaces) private var faces
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.6) {
            ForEach(document.blocks) { block in
                blockView(block)
            }
        }
        .foregroundStyle(textColor)
        .environment(\.layoutDirection, direction.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private func blockView(_ block: TafsirDocument.Block) -> some View {
        let text = Text(TafsirDocument.attributedString(block, fontSize: fontSize, direction: direction, faces: faces))
            .lineSpacing(fontSize * (direction.isRightToLeft ? 0.35 : 0.22))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.layoutDirection, block.isArabic || direction.isRightToLeft ? .rightToLeft : .leftToRight)
        switch block.kind {
        case .heading(let level):
            text
                .foregroundStyle(headingColor)
                .padding(.top, block.id == 0 ? 0 : fontSize * 0.25)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(Self.headingLevel(level))
        case .listItem(let marker, let depth):
            let markerText = markerString(marker)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: markerText)
                    .font(QuranFaces.chromeFont(size: fontSize, weight: .regular))
                    .frame(minWidth: fontSize, alignment: .trailing)
                    .accessibilityHidden(markerText.isEmpty)
                text
            }
            .padding(.leading, CGFloat(depth) * fontSize)
            .accessibilityElement(children: .combine)
        case .paragraph:
            text
        }
    }

    /// "•", the ordinal in the reader's digits followed by ".", or nothing for a continuation.
    private func markerString(_ marker: TafsirDocument.ListMarker) -> String {
        switch marker {
        case .bullet: "•"
        case .ordinal(let number): l10n.string(number, grouped: false) + "."
        case .continuation: ""
        }
    }

    private static func headingLevel(_ level: Int) -> AccessibilityHeadingLevel {
        switch level {
        case 1: .h1
        case 2: .h2
        case 3: .h3
        default: .h4
        }
    }
}
