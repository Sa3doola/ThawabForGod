//
//  MarginMarker.swift
//  ThawabForGod
//

import Foundation

/// A label in a Mushaf page's outer margin, beside the line where it applies: the start of a juz,
/// hizb or quarter (rub), and the sajdah ayahs. Only a build with the printed pages has any.
nonisolated struct MushafMarginMarker: Hashable, Sendable {
    nonisolated enum Kind: Hashable, Sendable {
        /// A juz begins (always also a hizb start).
        case juz(Int)
        /// A hizb begins without a new juz.
        case hizb(Int)
        /// A quarter of a hizb begins: `quarter` is 1 (¼), 2 (½) or 3 (¾).
        case quarter(Int, hizb: Int)
        case sajdah
    }

    /// Layout line number on the page (`MushafLine.number`).
    let line: Int
    /// The ayah the marker belongs to: it starts the division, or holds the sajdah.
    let ayah: VerseReference
    let kind: Kind

    /// The page's markers in line order, from the metadata's starts and sajdahs on this page.
    ///
    /// A division starts on the line of its first ayah's first word (where ۞ is printed). A sajdah
    /// sits on the line of the word carrying ۩ (Hafs text) or, when no word does, on the line where
    /// its ayah ends.
    static func markers(on page: MushafPage, metadata: QuranMetadata) -> [MushafMarginMarker] {
        var result: [MushafMarginMarker] = []
        let juzStarts = Set(metadata.juz.filter { $0.page == page.number }.map(\.ayah))
        for start in metadata.rub where start.page == page.number {
            guard let line = page.lines.first(where: { line in
                line.segments.contains { $0.reference == start.ayah && !$0.words.isEmpty }
            }) else { continue }
            let hizb = (start.number - 1) / 4 + 1
            let quarter = (start.number - 1) % 4
            let kind: Kind
            if quarter > 0 {
                kind = .quarter(quarter, hizb: hizb)
            } else if juzStarts.contains(start.ayah) {
                kind = .juz((hizb + 1) / 2)
            } else {
                kind = .hizb(hizb)
            }
            result.append(MushafMarginMarker(line: line.number, ayah: start.ayah, kind: kind))
        }
        for sajdah in metadata.sajdahs where sajdah.page == page.number {
            let segments = page.lines.flatMap { line in line.segments.map { (line.number, $0) } }.filter { $0.1.reference == sajdah.ayah }
            let line = segments.first { $0.1.words.contains { $0.contains("۩") } }?.0 ?? segments.first { $0.1.endsAyah }?.0
            if let line {
                result.append(MushafMarginMarker(line: line, ayah: sajdah.ayah, kind: .sajdah))
            }
        }
        return result.sorted { $0.line < $1.line }
    }
}
