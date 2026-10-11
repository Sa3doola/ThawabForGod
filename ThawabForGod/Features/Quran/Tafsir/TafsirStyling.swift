//
//  TafsirStyling.swift
//  ThawabForGod
//

import SwiftUI

/// The half of Mushaf's `TafsirMarkup.swift` that needs SwiftUI's `Font`: one block to styled text.
///
/// Sizes are points, already scaled for Dynamic Type by the caller, and every face here is set at a
/// fixed size for that reason (`font(_:size:)` and `chromeFont` are both `fixedSize`). Quran words
/// are only ever *drawn* by this file, never altered: a quote's characters reach the
/// `AttributedString` exactly as the pack wrote them.
nonisolated extension TafsirDocument {
    /// First strong right-to-left isolate … pop: keeps an Arabic run's punctuation, digits and
    /// brackets in place inside left-to-right text.
    static let rightToLeftIsolate = "\u{2067}", popIsolate = "\u{2069}"

    /// One block's styled text. `direction` is the pack's: Arabic runs inside a left-to-right
    /// pack are isolated and set in KFGQPC Hafs; Quran quotes use Hafs in every pack.
    /// `fontSize` is in points and already scaled for Dynamic Type by the caller.
    static func attributedString(
        _ block: Block, fontSize: CGFloat, direction: TextDirection, faces: QuranFaces
    ) -> AttributedString {
        let size = Self.fontSize(for: block.kind, base: fontSize)
        let isHeading = block.isHeading
        var result = AttributedString()
        for run in block.runs {
            let usesHafs = run.style.contains(.quran) || (run.style.contains(.arabic) && !direction.isRightToLeft)
            let isolates = run.style.contains(.arabic) && !direction.isRightToLeft && !block.isArabic
            var text = AttributedString(isolates ? rightToLeftIsolate + run.text + popIsolate : run.text)
            var runSize = run.style.contains(.superscript) ? size * 0.68 : size
            if usesHafs { runSize *= hafsScale(direction) }
            var font: Font = usesHafs
                ? faces.font(.ayahText, size: runSize)
                : QuranFaces.chromeFont(size: runSize, weight: run.style.contains(.bold) || isHeading ? .semibold : .regular)
            if run.style.contains(.italic) { font = font.italic() }
            text.font = font
            if run.style.contains(.superscript) { text.baselineOffset = size * 0.35 }
            result += text
        }
        return result
    }

    /// KFGQPC Hafs looks small for its point size beside Latin text, so quotes in an English
    /// tafsir are enlarged; beside Arabic prose the same size matches (and a larger one would
    /// open up the line spacing of every line holding a quote).
    static func hafsScale(_ direction: TextDirection) -> CGFloat {
        direction.isRightToLeft ? 1 : 1.12
    }

    /// Heading sizes relative to the body text.
    static func fontSize(for kind: Kind, base: CGFloat) -> CGFloat {
        switch kind {
        case .heading(let level): base * ([1.3, 1.2, 1.1, 1.05][min(max(level, 1), 4) - 1])
        case .paragraph, .listItem: base
        }
    }
}
