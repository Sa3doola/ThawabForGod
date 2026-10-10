//
//  MushafPageAccessibility.swift
//  ThawabForGod
//

import SwiftUI

/// One VoiceOver element on a Mushaf page. Words are never elements of their own: an ayah, even
/// split across lines, is read as a single element (Mushaf's Phase 0.5 behaviour).
nonisolated enum MushafPageElement: Hashable, Sendable {
    case surahHeader(Int)
    case basmala(line: Int)
    case ayah(VerseReference)

    /// The page's elements in reading order.
    static func elements(on page: MushafPage) -> [MushafPageElement] {
        var result: [MushafPageElement] = []
        var seen = Set<VerseReference>()
        for line in page.lines {
            switch line.kind {
            case .surahHeader(let surah):
                result.append(.surahHeader(surah))
            case .basmala:
                result.append(.basmala(line: line.number))
            case .text:
                for segment in line.segments where seen.insert(segment.reference).inserted {
                    result.append(.ayah(segment.reference))
                }
            }
        }
        return result
    }

    /// The part of `ayah` printed on `page` — an ayah can continue on the next page. VoiceOver
    /// reads it, in the Hafs text even when the page is drawn in V2 glyph codes.
    static func words(of ayah: VerseReference, on page: MushafPage) -> String {
        page.lines
            .flatMap(\.segments)
            .filter { $0.reference == ayah }
            .flatMap(\.words)
            .joined(separator: " ")
    }
}

/// Bounds of everything drawn for each element; the accessibility frame is their union.
nonisolated struct MushafElementBoundsKey: PreferenceKey {
    /// A flat list, appended word by word and grouped once when resolved: a dictionary merged per
    /// word cost ~16 ms of main thread at launch and on every page turn (Mushaf 8.2).
    static var defaultValue: [MushafElementAnchor] { [] }

    static func reduce(value: inout [MushafElementAnchor], nextValue: () -> [MushafElementAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

/// One drawn piece of a page element (a word of an ayah, a header, the basmala).
nonisolated struct MushafElementAnchor {
    let element: MushafPageElement
    let bounds: Anchor<CGRect>
}

/// Each element's bounds resolved in the page content's coordinate space.
nonisolated struct MushafElementFramesKey: PreferenceKey {
    static let defaultValue: [MushafPageElement: CGRect] = [:]

    static func reduce(value: inout [MushafPageElement: CGRect], nextValue: () -> [MushafPageElement: CGRect]) {
        value.merge(nextValue()) { $0.union($1) }
    }

    /// Resolves the anchors collected from the page's lines.
    static func frames(_ anchors: [MushafElementAnchor], in proxy: GeometryProxy) -> [MushafPageElement: CGRect] {
        var frames: [MushafPageElement: CGRect] = [:]
        for anchor in anchors {
            frames[anchor.element, default: .null] = frames[anchor.element, default: .null].union(proxy[anchor.bounds])
        }
        return frames
    }
}

/// The synthetic VoiceOver children of a page: one per ayah, header and basmala, in reading order.
/// Used with `accessibilityChildren`, which replaces the per-word views outright.
struct MushafPageAccessibilityLayer: View {
    let page: MushafPage
    let basmala: String
    let surahs: [Surah]
    var marginMarkers: [MushafMarginMarker] = []
    let selectedAyah: VerseReference?
    let frames: [MushafPageElement: CGRect]
    let onSelect: (VerseReference) -> Void

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        let elements = MushafPageElement.elements(on: page)
        ZStack(alignment: .topLeading) {
            ForEach(Array(elements.enumerated()), id: \.element) { index, element in
                if let frame = frames[element], !frame.isNull {
                    Color.clear
                        .contentShape(.rect)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .modifier(ElementAccessibility(
                            element: element,
                            page: page,
                            basmala: basmala,
                            surahName: surahName(element),
                            margin: marginMarkers.filter { MushafPageElement.ayah($0.ayah) == element }.map(\.kind),
                            isSelected: element == selectedAyah.map(MushafPageElement.ayah),
                            onSelect: onSelect
                        ))
                        // Reading order, not on-screen position: VoiceOver would otherwise sort
                        // overlapping multi-line frames unpredictably.
                        .accessibilitySortPriority(Double(elements.count - index))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Frames are absolute; keep `.position` from being mirrored in the right-to-left pager.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func surahName(_ element: MushafPageElement) -> String {
        let number: Int
        switch element {
        case .surahHeader(let surah): number = surah
        case .ayah(let reference): number = reference.surah
        case .basmala: return ""
        }
        return surahs.indices.contains(number - 1) ? surahs[number - 1].name(in: l10n.language) : ""
    }
}

private struct ElementAccessibility: ViewModifier {
    let element: MushafPageElement
    let page: MushafPage
    let basmala: String
    let surahName: String
    /// Margin labels that belong to this ayah, read as extra content.
    let margin: [MushafMarginMarker.Kind]
    let isSelected: Bool
    let onSelect: (VerseReference) -> Void

    @Environment(LocalizationManager.self) private var l10n

    func body(content: Content) -> some View {
        switch element {
        case .surahHeader:
            content
                .accessibilityElement()
                .accessibilityLabel(Text(l10n.string(.quranSurahHeading, surahName)))
                .accessibilityAddTraits(.isHeader)
        case .basmala:
            content
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: basmala))
                .accessibilityAddTraits(.isStaticText)
        case .ayah(let reference):
            content
                .accessibilityElement()
                .accessibilityLabel(Text(l10n.string(
                    .quranSurahAyah,
                    surahName,
                    l10n.string(reference.verse, grouped: false)
                )))
                .accessibilityValue(Text(verbatim: MushafPageElement.words(of: reference, on: page)))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { onSelect(reference) }
                // A juz, hizb, quarter or sajdah label beside the ayah, as custom content (read
                // with "more content"), so the ayah stays one element. One entry holding every
                // label on the ayah — it is rare for there to be more than one.
                .accessibilityCustomContent(
                    AccessibilityCustomContentKey(Text(l10n.string(.quranMargin)), id: "margin"),
                    margin.isEmpty ? nil : Text(margin.map { MarginMarkerLabel.title($0, l10n: l10n) }.joined(separator: ", "))
                )
        }
    }
}
