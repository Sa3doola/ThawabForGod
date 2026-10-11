//
//  TranslationDocument.swift
//  ThawabForGod
//

import Foundation

/// A translation's text split into what the reader draws: plain runs, `*italic*` runs and footnote
/// markers. Raw HTML never reaches the app; the pack builder already turned the markup into
/// `[[fn:ID]]` tokens. Foundation only: the styled `AttributedString` is an extension in the views.
nonisolated struct TranslationDocument: Equatable, Sendable {
    enum Piece: Equatable, Sendable {
        case text(String, italic: Bool)
        /// `number` counts the ayah's footnotes from 1, in reading order.
        case footnote(number: Int, id: String, note: String)
    }

    let pieces: [Piece]

    var footnotes: [(number: Int, id: String, note: String)] {
        pieces.compactMap { if case .footnote(let number, let id, let note) = $0 { (number, id, note) } else { nil } }
    }

    /// Text without markers or emphasis: for VoiceOver, copying and sharing.
    var plainText: String {
        pieces.map { if case .text(let text, _) = $0 { text } else { "" } }.joined()
    }

    /// Parses `[[fn:ID]]` tokens (resolved against `footnotes`) and `*…*` italics. A token whose
    /// note is missing or empty is dropped; an unpaired `*` stays literal.
    init(text: String, footnotes: [String: String]) {
        var pieces: [Piece] = []
        var number = 0
        var rest = Substring(text)
        while let token = rest.firstMatch(of: /\[\[fn:([^\]]+)\]\]/) {
            pieces += Self.italics(rest[..<token.range.lowerBound])
            let id = String(token.1)
            if let note = footnotes[id], !note.isEmpty {
                number += 1
                pieces.append(.footnote(number: number, id: id, note: note))
            }
            rest = rest[token.range.upperBound...]
        }
        pieces += Self.italics(rest)
        self.pieces = pieces
    }

    init(_ translation: TranslationText) {
        self.init(text: translation.text, footnotes: translation.footnotes)
    }

    // A compiled `Regex` is never mutated after construction and is only ever read, but the type
    // is not marked `Sendable`; that is the whole reason for the annotation. (A literal regex would
    // end in `*/`, which reads as a comment end, hence the string form.)
    nonisolated(unsafe) private static let italic = try! Regex(#"\*([^*]+)\*"#, as: (Substring, Substring).self)

    private static func italics(_ text: Substring) -> [Piece] {
        var pieces: [Piece] = []
        var rest = text
        while let match = rest.firstMatch(of: italic) {
            if match.range.lowerBound > rest.startIndex { pieces.append(.text(String(rest[..<match.range.lowerBound]), italic: false)) }
            pieces.append(.text(String(match.1), italic: true))
            rest = rest[match.range.upperBound...]
        }
        if !rest.isEmpty { pieces.append(.text(String(rest), italic: false)) }
        return pieces
    }

    /// URL scheme of footnote markers. Never opened: `TranslationTextView` handles it in-app.
    static let footnoteScheme = "footnote"

    static func footnoteID(from url: URL) -> String? {
        url.scheme == footnoteScheme ? url.host() ?? url.path() : nil
    }
}
