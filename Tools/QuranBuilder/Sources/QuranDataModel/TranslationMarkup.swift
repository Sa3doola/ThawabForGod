import Foundation

/// Converts QUL translation text into the pack format (docs/05): plain text with `[[fn:ID]]`
/// footnote tokens and `*…*` italics, never HTML. Shared by the pipeline and its tests.
public enum TranslationMarkup {
    public enum ConversionError: Error, Equatable, CustomStringConvertible {
        case unresolvedFootnote(id: String)
        case unusedFootnote(id: String)
        case reservedSequence(String)

        public var description: String {
            switch self {
            case .unresolvedFootnote(let id): "footnote \(id) is referenced but has no note"
            case .unusedFootnote(let id): "footnote \(id) has a note but is never referenced"
            case .reservedSequence(let text): "text already contains the token syntax: \(text.prefix(80))"
            }
        }
    }

    /// QUL "footnote tags" format: `<sup foot_note="ID">N</sup>` in the text, notes keyed by ID.
    /// Returns the text with `[[fn:ID]]` tokens and the notes, both stripped of any other HTML.
    /// Every reference must have a note and every note a reference.
    public static func convertFootnoteTags(text: String, footnotes: [String: String]) throws -> (text: String, footnotes: [String: String]) {
        guard !text.contains("[["), !text.contains("]]") else { throw ConversionError.reservedSequence(text) }
        var used = Set<String>()
        var converted = ""
        var rest = Substring(text)
        let pattern = /<sup\s+foot_note\s*=\s*"([^"]+)"\s*>[^<]*<\/sup>/
        while let match = rest.firstMatch(of: pattern) {
            let id = String(match.1)
            guard footnotes[id] != nil else { throw ConversionError.unresolvedFootnote(id: id) }
            used.insert(id)
            converted += rest[..<match.range.lowerBound]
            converted += "[[fn:\(id)]]"
            rest = rest[match.range.upperBound...]
        }
        converted += rest
        if let unused = Set(footnotes.keys).subtracting(used).sorted().first { throw ConversionError.unusedFootnote(id: unused) }
        return (stripHTML(converted), footnotes.mapValues(stripHTML))
    }

    /// Plain text: block tags (`p`, `div`, `br`, `li`) become a space, other tags are removed,
    /// the basic entities are decoded and runs of whitespace collapse to one space.
    public static func stripHTML(_ text: String) -> String {
        var result = text.replacing(/<\s*\/?\s*(p|div|br|li)\b[^>]*>/.ignoresCase(), with: " ")
        result = result.replacing(/<[^>]*>/, with: "")
        for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// The text without footnote tokens or italic marks, for the search index.
    public static func searchText(_ text: String) -> String {
        text.replacing(/\[\[fn:[^\]]+\]\]/, with: "").replacingOccurrences(of: "*", with: "")
            .replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Footnote ids referenced by `[[fn:ID]]` tokens, in order.
    public static func footnoteIDs(in text: String) -> [String] {
        text.matches(of: /\[\[fn:([^\]]+)\]\]/).map { String($0.1) }
    }
}
