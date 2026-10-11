//
//  TafsirDocument.swift
//  ThawabForGod
//

import Foundation

/// A tafsir entry's HTML subset as blocks of styled runs: headings, paragraphs and list items,
/// with bold, italic, superscript, Arabic runs and Quran quotes. A small hand-written parser: no
/// `NSAttributedString(html:)`, which is main-thread only, slow, and may load resources.
///
/// Mushaf's `TafsirDocument`, split in two: this file is the half that is pure Swift, and
/// `TafsirStyling.swift` is the half that needs SwiftUI's `Font`.
///
/// Tolerant by design: the pipeline that built the packs already rejected anything outside the
/// subset, so an unexpected tag here is skipped and its text kept.
///
/// Every declaration says `nonisolated` because the module's default is the main actor and this
/// type is parsed off it (`parsed(html:)`).
nonisolated struct TafsirDocument: Equatable, Sendable {
    nonisolated struct Style: OptionSet, Hashable, Sendable {
        let rawValue: Int
        static let bold = Style(rawValue: 1 << 0)
        static let italic = Style(rawValue: 1 << 1)
        static let superscript = Style(rawValue: 1 << 2)
        /// Inside `lang="ar"`: right-to-left, and set in KFGQPC Hafs inside a left-to-right pack.
        static let arabic = Style(rawValue: 1 << 3)
        /// A Quran quote (`class="quran"`): always KFGQPC Hafs, whose Uthmani marks other fonts lack.
        static let quran = Style(rawValue: 1 << 4)
    }

    nonisolated struct Run: Equatable, Sendable {
        var text: String
        var style: Style
    }

    /// What starts a list item. A number is data here and is formatted where it is drawn, because
    /// the digit system is the reader's choice and not something a parser can know.
    nonisolated enum ListMarker: Equatable, Sendable {
        case bullet
        /// An ordered list's item; the number is formatted where it is drawn.
        case ordinal(Int)
        /// A further paragraph of the same item: no marker.
        case continuation
    }

    nonisolated enum Kind: Equatable, Sendable {
        case paragraph
        /// `h1`…`h4`.
        case heading(level: Int)
        case listItem(marker: ListMarker, depth: Int)
    }

    nonisolated struct Block: Equatable, Sendable, Identifiable {
        let id: Int
        let kind: Kind
        let runs: [Run]

        var text: String { runs.map(\.text).joined() }
        /// Every run is Arabic: the block reads right-to-left even inside a left-to-right pack.
        var isArabic: Bool { !runs.isEmpty && runs.allSatisfy { $0.style.contains(.arabic) } }
        var isHeading: Bool { if case .heading = kind { true } else { false } }
    }

    let blocks: [Block]

    /// The text without markup, one block per line: for copying and tests. `number` formats an
    /// ordered item's number, so the caller's digit system applies.
    func plainText(number: (Int) -> String) -> String {
        blocks.map { block in
            switch block.kind {
            case .listItem(.bullet, _): "• \(block.text)"
            case .listItem(.ordinal(let n), _): "\(number(n)). \(block.text)"
            case .listItem(.continuation, _), .paragraph, .heading: block.text
            }
        }.joined(separator: "\n")
    }

    init(html: String) {
        var parser = Parser()
        parser.parse(html)
        blocks = parser.blocks
    }

    /// The same parse, off the main actor. A surah's introduction is tens of kilobytes of HTML
    /// walked character by character, and the module's default isolation would otherwise run that
    /// on the main actor in the middle of a push animation.
    @concurrent static func parsed(html: String) async -> TafsirDocument {
        TafsirDocument(html: html)
    }

    // MARK: Parser

    private nonisolated struct Parser {
        // A compiled `Regex` is never mutated after construction and is only ever read, but the
        // type is not marked `Sendable`; that is the whole reason for the annotation.
        nonisolated(unsafe) static let whitespace = try! Regex("[ \\t\\r\\n]+")

        var blocks: [Block] = []
        private var runs: [Run] = []
        private var kind: Kind = .paragraph
        /// Open inline elements and what each adds to the style.
        private var inline: [(tag: String, style: Style)] = []
        /// Open `div`s, and whether each one is an Arabic run.
        private var divs: [Bool] = []
        /// Open lists: ordered or not, and the items so far.
        private var lists: [(ordered: Bool, count: Int)] = []
        /// The current list item already produced a block (later paragraphs get no marker).
        private var itemHasBlock = false

        private var style: Style {
            var style = inline.reduce(Style()) { $0.union($1.style) }
            if divs.contains(true) { style.insert(.arabic) }
            return style
        }

        mutating func parse(_ html: String) {
            var rest = Substring(html)
            while let open = rest.firstIndex(of: "<") {
                text(rest[..<open])
                guard let close = rest[open...].firstIndex(of: ">") else {
                    rest = rest[open...]
                    break
                }
                tag(rest[rest.index(after: open)..<close])
                rest = rest[rest.index(after: close)...]
            }
            text(rest)
            flush()
        }

        private mutating func tag(_ source: Substring) {
            let body = source.trimmingCharacters(in: .whitespaces)
            let isClosing = body.hasPrefix("/")
            let nameAndAttributes = isClosing ? body.dropFirst() : Substring(body)
            let name = String(nameAndAttributes.prefix { $0.isLetter || $0.isNumber }).lowercased()
            let attributes = String(nameAndAttributes.dropFirst(name.count))
            let isArabic = attributes.contains(#"lang="ar""#)
            let isQuran = attributes.contains(#"class="quran""#)

            switch (name, isClosing) {
            case ("p", false):
                startBlock(keepingItem: true)
            case ("p", true):
                flush()
            case ("h1", false), ("h2", false), ("h3", false), ("h4", false):
                flush()
                kind = .heading(level: Int(name.dropFirst()) ?? 3)
            case ("h1", true), ("h2", true), ("h3", true), ("h4", true):
                flush()
            case ("ul", false), ("ol", false):
                flush()
                lists.append((name == "ol", 0))
            case ("ul", true), ("ol", true):
                flush()
                _ = lists.popLast()
            case ("li", false):
                flush()
                if lists.isEmpty { lists.append((false, 0)) }
                lists[lists.count - 1].count += 1
                let list = lists[lists.count - 1]
                kind = .listItem(marker: list.ordered ? .ordinal(list.count) : .bullet, depth: lists.count - 1)
                itemHasBlock = false
            case ("li", true):
                flush()
                kind = .paragraph
            case ("br", _):
                append("\n")
            case ("div", false):
                flush()
                divs.append(isArabic)
            case ("div", true):
                flush()
                _ = divs.popLast()
            case ("b", false), ("strong", false):
                inline.append((name, .bold))
            case ("i", false), ("em", false):
                inline.append((name, .italic))
            case ("sup", false):
                inline.append((name, .superscript))
            case ("span", false):
                var added = Style()
                if isArabic { added.insert(.arabic) }
                if isQuran { added.insert([.quran, .arabic]) }
                inline.append((name, added))
            case (_, true):
                // Close the innermost open inline element with this name.
                if let index = inline.lastIndex(where: { $0.tag == name }) { inline.remove(at: index) }
            default:
                break   // Not in the subset: skipped, text kept.
            }
        }

        /// A `<p>` inside a list item continues the item instead of leaving it.
        private mutating func startBlock(keepingItem: Bool) {
            flush()
            if case .listItem = kind, keepingItem { return }
            kind = .paragraph
        }

        private mutating func text(_ source: Substring) {
            guard !source.isEmpty else { return }
            var decoded = String(source)
            if decoded.contains("&") {
                decoded = decoded.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&nbsp;", with: "\u{00A0}").replacingOccurrences(of: "&amp;", with: "&")
            }
            // HTML whitespace: runs of spaces, tabs and newlines read as one space.
            append(decoded.replacing(Self.whitespace, with: " "))
        }

        private mutating func append(_ text: String) {
            var text = text
            // No leading space at the start of a block or after a line break.
            if runs.isEmpty || runs.last?.text.hasSuffix("\n") == true {
                text = String(text.drop { $0 == " " })
            } else if runs.last?.text.hasSuffix(" ") == true, text.hasPrefix(" ") {
                text.removeFirst()
            }
            guard !text.isEmpty else { return }
            let style = self.style
            if let last = runs.last, last.style == style {
                runs[runs.count - 1].text += text
            } else {
                runs.append(Run(text: text, style: style))
            }
        }

        private mutating func flush() {
            // Trailing spaces and line breaks end with the block.
            while let last = runs.last {
                let trimmed = String(last.text.reversed().drop { $0 == " " || $0 == "\n" }.reversed())
                if trimmed.isEmpty { runs.removeLast() } else { runs[runs.count - 1].text = trimmed; break }
            }
            guard !runs.isEmpty else { return }
            var blockKind = kind
            if case .listItem(_, let depth) = kind {
                if itemHasBlock { blockKind = .listItem(marker: .continuation, depth: depth) }
                itemHasBlock = true
            }
            blocks.append(Block(id: blocks.count, kind: blockKind, runs: runs))
            runs = []
            if case .heading = kind { kind = .paragraph }
        }
    }
}
