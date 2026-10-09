import Foundation

/// Sanitizes QUL tafsir HTML to the subset the app renders (docs/05), in the pipeline, so the
/// app never sees anything else. Allowed: `p br b i h1–h4 ul ol li sup`, plus two markers:
/// `<div lang="ar">` / `<span lang="ar">` (an Arabic run) and `<span lang="ar" class="quran">`
/// (a Quran quote, drawn in KFGQPC Hafs). Output is canonical: lower-case tags, no other
/// attributes, `strong`→`b`, `em`→`i`, text escaped with `&amp; &lt; &gt;` only.
///
/// Tags that only wrap text (links, font, a `div`/`span` without a marker) are removed and
/// their text kept; every removal is counted in the report. Anything else fails, as does
/// markup that does not nest, so nothing is dropped silently.
public enum TafsirHTML {
    public enum SanitizeError: Error, Equatable, CustomStringConvertible {
        case unknownTag(String)
        case unbalanced(String)
        case unknownEntity(String)
        case strayBracket(String)
        case empty

        public var description: String {
            switch self {
            case .unknownTag(let tag): "unknown tag <\(tag)>"
            case .unbalanced(let detail): "unbalanced markup: \(detail)"
            case .unknownEntity(let entity): "unknown entity \(entity)"
            case .strayBracket(let context): "'<' that does not start a tag: \(context)"
            case .empty: "no text left after sanitizing"
            }
        }
    }

    /// What the sanitizer removed or renamed, by description, with counts.
    public struct Report: Equatable, Sendable {
        /// e.g. `<a>` (tag removed, text kept), `<!-- comment -->`.
        public var droppedTags: [String: Int] = [:]
        /// e.g. `div class=ar` (the attribute removed; the tag kept).
        public var droppedAttributes: [String: Int] = [:]
        /// e.g. `span class=qpc-hafs → span lang=ar class=quran`.
        public var mapped: [String: Int] = [:]

        public init() {}

        public var isEmpty: Bool { droppedTags.isEmpty && droppedAttributes.isEmpty && mapped.isEmpty }

        public mutating func merge(_ other: Report) {
            droppedTags.merge(other.droppedTags, uniquingKeysWith: +)
            droppedAttributes.merge(other.droppedAttributes, uniquingKeysWith: +)
            mapped.merge(other.mapped, uniquingKeysWith: +)
        }

        /// One line per entry, most frequent first.
        public var lines: [String] {
            func list(_ title: String, _ counts: [String: Int]) -> [String] {
                counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map { "\(title) \($0.key): \($0.value)" }
            }
            return list("dropped tag", droppedTags) + list("dropped attribute", droppedAttributes) + list("mapped", mapped)
        }
    }

    /// Tags kept as they are (after renaming `strong`/`em`). `div` and `span` are kept only
    /// with an Arabic marker.
    public static let allowedTags: Set<String> = ["p", "br", "b", "i", "h1", "h2", "h3", "h4", "ul", "ol", "li", "sup", "div", "span"]
    private static let renamed = ["strong": "b", "em": "i"]
    /// Wrappers whose text is kept and whose tag is dropped (reported).
    /// `s` (strikethrough) since 5.4: surah info 24 strikes out a lone full stop.
    private static let unwrapped: Set<String> = ["a", "font", "u", "s", "small", "big", "abbr", "cite", "q", "bdi", "bdo", "section", "article", "blockquote"]
    private static let voidTags: Set<String> = ["br"]
    private static let entities: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "#39": "'", "nbsp": "\u{00A0}"]

    public static func sanitize(_ html: String) throws -> (html: String, report: Report) {
        var report = Report()
        var output = ""
        var hasText = false
        /// Open elements as written in the source, and whether each one is kept in the output.
        var stack: [(source: String, output: String?)] = []
        var index = html.startIndex

        while index < html.endIndex {
            let character = html[index]
            if character == "<" {
                if html[index...].hasPrefix("<!--") {
                    guard let end = html[index...].range(of: "-->") else { throw SanitizeError.unbalanced("unterminated comment") }
                    report.droppedTags["<!-- comment -->", default: 0] += 1
                    index = end.upperBound
                    continue
                }
                guard let close = html[index...].firstIndex(of: ">"),
                      let tag = Tag(String(html[html.index(after: index)..<close]))
                else { throw SanitizeError.strayBracket(String(html[index...].prefix(40))) }
                index = html.index(after: close)

                if tag.isClosing {
                    guard let open = stack.popLast() else { throw SanitizeError.unbalanced("</\(tag.name)> without an open tag") }
                    guard open.source == tag.name else { throw SanitizeError.unbalanced("</\(tag.name)> closes <\(open.source)>") }
                    if let name = open.output { output += "</\(name)>" }
                    continue
                }

                let name = renamed[tag.name] ?? tag.name
                if name != tag.name { report.mapped["\(tag.name) → \(name)", default: 0] += 1 }
                if unwrapped.contains(name) {
                    report.droppedTags["<\(name)>", default: 0] += 1
                    if !tag.attributes.isEmpty { report.droppedAttributes[tag.attributeSummary, default: 0] += 1 }
                    if !tag.isSelfClosing { stack.append((tag.name, nil)) }
                    continue
                }
                guard allowedTags.contains(name) else { throw SanitizeError.unknownTag(tag.name) }

                var kept: String? = name
                var opening = "<\(name)>"
                switch name {
                case "div", "span":
                    let isArabic = tag.attributes["lang"]?.lowercased() == "ar"
                    let isQuran = name == "span" && tag.classes.contains("qpc-hafs")
                    if isQuran {
                        opening = #"<span lang="ar" class="quran">"#
                        report.mapped["\(tag.attributeSummaryWithName) → span lang=ar class=quran", default: 0] += 1
                        let rest = tag.attributes.filter { $0.key != "class" && $0.key != "lang" }
                        if !rest.isEmpty || tag.classes.count > 1 { report.droppedAttributes["\(tag.attributeSummaryWithName) (other attributes)", default: 0] += 1 }
                    } else if isArabic {
                        opening = #"<\#(name) lang="ar">"#
                        let rest = tag.attributes.filter { $0.key != "lang" }
                        for (key, value) in rest.sorted(by: { $0.key < $1.key }) {
                            report.droppedAttributes["\(name) \(key)=\(value)", default: 0] += 1
                        }
                    } else {
                        // No marker: a plain wrapper, so keep its text only.
                        kept = nil
                        report.droppedTags["<\(name)> without lang=ar (\(tag.attributeSummary))", default: 0] += 1
                    }
                default:
                    for (key, value) in tag.attributes.sorted(by: { $0.key < $1.key }) {
                        report.droppedAttributes["\(name) \(key)=\(value)", default: 0] += 1
                    }
                }
                if let kept, voidTags.contains(kept) {
                    output += "<\(kept)>"
                    continue
                }
                if tag.isSelfClosing { throw SanitizeError.unbalanced("<\(tag.name)/> is not a void element") }
                if kept != nil { output += opening }
                stack.append((tag.name, kept))
            } else if character == ">" {
                throw SanitizeError.strayBracket(String(html[..<index].suffix(20) + html[index...].prefix(20)))
            } else if character == "&" {
                guard let semicolon = html[index...].prefix(12).firstIndex(of: ";") else {
                    // A bare ampersand in text.
                    output += "&amp;"
                    index = html.index(after: index)
                    continue
                }
                let name = String(html[html.index(after: index)..<semicolon])
                let decoded: String
                if let named = entities[name] {
                    decoded = named
                } else if name.hasPrefix("#x") || name.hasPrefix("#X"), let code = UInt32(name.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(code) {
                    decoded = String(Character(scalar))
                } else if name.hasPrefix("#"), let code = UInt32(name.dropFirst()), let scalar = Unicode.Scalar(code) {
                    decoded = String(Character(scalar))
                } else {
                    throw SanitizeError.unknownEntity("&\(name);")
                }
                output += escape(decoded)
                hasText = hasText || !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                index = html.index(after: semicolon)
            } else {
                output += escape(String(character))
                hasText = hasText || !character.isWhitespace
                index = html.index(after: index)
            }
        }
        if let open = stack.last { throw SanitizeError.unbalanced("<\(open.source)> is never closed") }
        guard hasText else { throw SanitizeError.empty }
        return (output.trimmingCharacters(in: .whitespacesAndNewlines), report)
    }

    /// Tags that may appear in sanitized output, as written there (for tests).
    public static func tags(in html: String) -> [String] {
        html.matches(of: /<\/?[^>]*>/).map { String($0.output) }
    }

    /// Text without tags, entities decoded, whitespace collapsed: for the search index.
    public static func plainText(_ sanitized: String) -> String {
        var text = sanitized.replacing(/<\s*\/?\s*(p|div|br|li|h[1-4]|ul|ol)\b[^>]*>/, with: " ")
        text = text.replacing(/<[^>]*>/, with: "")
        text = text.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
        return text.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    /// One tag as written: `p`, `/p`, `br/`, `div class=ar lang=ar`, `span class="qpc-hafs"`.
    private struct Tag {
        let name: String
        let isClosing: Bool
        let isSelfClosing: Bool
        let attributes: [String: String]

        init?(_ source: String) {
            var body = source.trimmingCharacters(in: .whitespacesAndNewlines)
            isClosing = body.hasPrefix("/")
            if isClosing { body = String(body.dropFirst()).trimmingCharacters(in: .whitespaces) }
            isSelfClosing = body.hasSuffix("/")
            if isSelfClosing { body = String(body.dropLast()).trimmingCharacters(in: .whitespaces) }
            guard let match = body.prefixMatch(of: /([A-Za-z][A-Za-z0-9]*)/) else { return nil }
            name = String(match.1).lowercased()
            var attributes: [String: String] = [:]
            let rest = body[match.range.upperBound...]
            for attribute in rest.matches(of: /([A-Za-z_:][-A-Za-z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/) {
                attributes[String(attribute.1).lowercased()] = String(attribute.2 ?? attribute.3 ?? attribute.4 ?? "")
            }
            // Anything that is not an attribute (a stray quote, say) makes this not a tag.
            let leftover = rest.replacing(/([A-Za-z_:][-A-Za-z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/, with: "")
            guard leftover.allSatisfy(\.isWhitespace), !(isClosing && !attributes.isEmpty) else { return nil }
            self.attributes = attributes
        }

        var classes: Set<String> {
            Set((attributes["class"] ?? "").split(whereSeparator: \.isWhitespace).map(String.init))
        }

        /// `class=ar lang=ar`, sorted, for the report.
        var attributeSummary: String {
            attributes.isEmpty ? "no attributes" : attributes.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        }

        var attributeSummaryWithName: String {
            attributes.isEmpty ? name : "\(name) \(attributeSummary)"
        }
    }
}
