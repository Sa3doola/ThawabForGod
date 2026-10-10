//
//  QuranTextFallback.swift
//  ThawabForGod
//

import Foundation

/// Which stretches of an ayah KFGQPC Hafs cannot draw, as ranges of the stored string.
///
/// **The mark is U+06DF**, the small circle over a letter that is written and not read (the alif
/// after the waw of a plural verb, say). It is a combining mark, and Tanzil's text uses it as one.
/// Hafs has a glyph for it, but the wrong kind: a *spacing* glyph, a wide dotted circle with an
/// advance of its own and no anchor, set after its letter instead of over it. Amiri Quran draws the
/// same scalar as an anchored mark, so the stretch is set in Amiri and no character changes
/// anywhere. The full (QUL) build never contains U+06DF, so for it every question here is answered
/// `false`; at each of the 3,988 positions where Tanzil has U+06DF, that build has U+0652 (the
/// evidence is in section 8 of the design note).
///
/// A check that every scalar has a glyph in Hafs passes on Tanzil's text and proves nothing: the
/// glyph exists. What tells the two faces apart is its advance, which is what the tests measure.
///
/// **A base that stands free takes only itself; a base that joins takes its whole word.** A letter
/// that connects to its neighbours is shaped by them, and a cluster shaped alone in another face
/// loses its join: the neighbours would be drawn in one face and the letter between them in a
/// second, with a break in the stroke. Setting the whole word in one face keeps every join inside
/// it. Only 27 of the 3,988 occurrences in the Tanzil text join; the rest are one letter.
///
/// See docs/quran-migration/design/M5.0.md.
nonisolated enum QuranTextFallback {
    /// U+06DF ARABIC SMALL HIGH ROUNDED ZERO: Tanzil's mark for a letter written and not read.
    static let mark: Unicode.Scalar = "\u{06DF}"

    /// The one decision: `true` draws a free-standing base as its own run, `false` sets every
    /// affected word whole. See docs/quran-migration/design/M5.0.md.
    static let usesClusterRuns = true

    nonisolated struct Occurrence: Equatable, Sendable {
        /// The `Character` carrying the mark: the base letter and its marks.
        let cluster: Range<String.Index>
        /// The whitespace-delimited word that contains it.
        let word: Range<String.Index>
        /// The first scalar of `cluster`.
        let base: Unicode.Scalar
        /// The base joins the letter before it or the letter after it.
        let isJoined: Bool
    }

    /// One pass, no allocation. `false` for every ayah of the full build.
    static func isNeeded(in text: String) -> Bool {
        text.unicodeScalars.contains(mark)
    }

    /// Every occurrence of `mark`, in order. Empty when `isNeeded` is false.
    static func occurrences(in text: String) -> [Occurrence] {
        guard isNeeded(in: text) else { return [] }
        var result: [Occurrence] = []
        var index = text.startIndex
        while index < text.endIndex {
            if text[index].isWhitespace {
                index = text.index(after: index)
                continue
            }
            let wordStart = index
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }
            let word = wordStart..<index
            var cursor = wordStart
            while cursor < word.upperBound {
                let next = text.index(after: cursor)
                if text[cursor].unicodeScalars.contains(mark) {
                    result.append(occurrence(at: cursor, next: next, word: word, in: text))
                }
                cursor = next
            }
        }
        return result
    }

    /// What to draw in the fallback face: ascending, non-overlapping, `Character`-aligned.
    static func ranges(in text: String) -> [Range<String.Index>] {
        guard isNeeded(in: text) else { return [] }
        var result: [Range<String.Index>] = []
        let all = occurrences(in: text)
        var start = 0
        while start < all.count {
            var end = start + 1
            while end < all.count, all[end].word == all[start].word { end += 1 }
            let group = all[start..<end]
            if !usesClusterRuns || group.contains(where: \.isJoined) {
                result.append(all[start].word)
            } else {
                result.append(contentsOf: group.map(\.cluster))
            }
            start = end
        }
        return result
    }

    // MARK: Occurrences

    private static func occurrence(
        at index: String.Index,
        next: String.Index,
        word: Range<String.Index>,
        in text: String
    ) -> Occurrence {
        let base = text[index].unicodeScalars.first ?? mark
        let joined: Bool
        if isMarkOrFormat(base) {
            // No letter to carry the mark: the whole word is the safe answer.
            joined = true
        } else {
            let previous = neighbour(before: index, in: word, of: text)
            let following = neighbour(after: next, in: word, of: text)
            joined = (previous.map(joinsForward) ?? false)
                || (joinsForward(base) && (following.map(joinsBackward) ?? false))
        }
        return Occurrence(cluster: index..<next, word: word, base: base, isJoined: joined)
    }

    /// The first scalar of the nearest earlier `Character` in the word that is a letter, not a mark.
    private static func neighbour(before index: String.Index, in word: Range<String.Index>, of text: String) -> Unicode.Scalar? {
        var cursor = index
        while cursor > word.lowerBound {
            cursor = text.index(before: cursor)
            if let scalar = text[cursor].unicodeScalars.first, !isMarkOrFormat(scalar) { return scalar }
        }
        return nil
    }

    /// The first scalar of the nearest later `Character` in the word that is a letter, not a mark.
    private static func neighbour(after index: String.Index, in word: Range<String.Index>, of text: String) -> Unicode.Scalar? {
        var cursor = index
        while cursor < word.upperBound {
            if let scalar = text[cursor].unicodeScalars.first, !isMarkOrFormat(scalar) { return scalar }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    private static func isMarkOrFormat(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .format: true
        default: false
        }
    }

    // MARK: Joining (Unicode ArabicShaping.txt)

    private static func isArabicLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0620...0x064A, 0x066E...0x06D3, 0x06D5, 0x06EE, 0x06EF, 0x06FA...0x06FC, 0x06FF: true
        default: false
        }
    }

    private static func isNonJoining(_ scalar: Unicode.Scalar) -> Bool {
        !isArabicLetter(scalar) || scalar.value == 0x0621 || scalar.value == 0x0674
    }

    private static func isRightJoining(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0622...0x0625, 0x0627, 0x0629, 0x062F...0x0632, 0x0648, 0x0671...0x0673,
             0x0675...0x0677, 0x0688...0x0699, 0x06C0, 0x06C3...0x06CB, 0x06CD, 0x06CF,
             0x06D2, 0x06D3, 0x06D5, 0x06EE, 0x06EF: true
        default: false
        }
    }

    /// Tatweel joins both ways; otherwise a letter that is neither non-joining nor right-joining.
    private static func joinsForward(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.value == 0x0640 { return true }
        return isArabicLetter(scalar) && !isNonJoining(scalar) && !isRightJoining(scalar)
    }

    private static func joinsBackward(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.value == 0x0640 { return true }
        return isArabicLetter(scalar) && !isNonJoining(scalar)
    }
}
