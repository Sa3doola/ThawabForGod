//
//  TafsirDocumentTests.swift
//  ThawabForGodTests
//

import SwiftUI
import Testing
@testable import ThawabForGod

/// The tafsir HTML subset → blocks → styled text. Ported from Mushaf's `TafsirMarkupTests`.
///
/// Changes from Mushaf, each one a rewrite and not a weakening:
/// - a list item's marker is a `ListMarker` (`.bullet`, `.ordinal(n)`, `.continuation`) where Mushaf
///   compared a string: "•" is `.bullet`, "1." … "3." is `.ordinal(1)` … `.ordinal(3)`, and "" is
///   `.continuation`;
/// - `plainText` takes a closure for an ordered item's number; the expectations pass `{ String($0) }`,
///   so they are the strings Mushaf asserted;
/// - anything that read a font or a size takes `faces:`. The tests that only compare chrome text use
///   `QuranFaces.unavailable`, which draws the app's own face and so does not depend on a registered
///   one; the tests that compare a KFGQPC Hafs run use `QuranFaces.launch`, the faces that registered
///   in this process, and keep Mushaf's first assertion that the face is there.
///
/// Arabic is compared by unicode scalars where a string holds combining marks, because `String ==`
/// compares canonical equivalence and would pass a decomposed or reordered copy.
@MainActor
struct TafsirDocumentTests {
    typealias Doc = TafsirDocument

    /// Mushaf's `FontRegistrar.registerBundledFonts()` returned the registered faces; here the launch set.
    let faces = QuranFaces.launch

    private func scalars(_ text: String) -> [Unicode.Scalar] { Array(text.unicodeScalars) }

    private func plain(_ doc: Doc) -> String { doc.plainText(number: { String($0) }) }

    @Test func headingsAndParagraphs() {
        let doc = Doc(html: "<h3>Title</h3><p>One <b>two</b> <i>three</i>.</p><h1>Big</h1><h4>Small</h4>")
        #expect(doc.blocks.map(\.kind) == [.heading(level: 3), .paragraph, .heading(level: 1), .heading(level: 4)])
        #expect(doc.blocks[1].runs == [
            .init(text: "One ", style: []), .init(text: "two", style: .bold), .init(text: " ", style: []),
            .init(text: "three", style: .italic), .init(text: ".", style: []),
        ])
        #expect(plain(doc) == "Title\nOne two three.\nBig\nSmall")
        #expect(Doc.fontSize(for: .heading(level: 1), base: 10) > Doc.fontSize(for: .heading(level: 4), base: 10))
    }

    @Test func nestedInlineStylesCombine() {
        let doc = Doc(html: "<p><b>bold <i>both</i></b> plain</p>")
        #expect(doc.blocks[0].runs == [
            .init(text: "bold ", style: .bold), .init(text: "both", style: [.bold, .italic]), .init(text: " plain", style: []),
        ])
    }

    /// Mushaf's `marker` strings, rewritten as `ListMarker`: "•" → `.bullet`, "1."…"3." → `.ordinal(1)`…`.ordinal(3)`,
    /// "" → `.continuation`.
    @Test func lists() {
        let doc = Doc(html: "<ul><li>one</li><li>two <b>x</b></li></ul><ol><li>a</li><li><p>b</p><p>c</p></li><li>d<ul><li>inner</li></ul></li></ol><p>after</p>")
        #expect(doc.blocks.map(\.kind) == [
            .listItem(marker: .bullet, depth: 0), .listItem(marker: .bullet, depth: 0),
            .listItem(marker: .ordinal(1), depth: 0), .listItem(marker: .ordinal(2), depth: 0), .listItem(marker: .continuation, depth: 0),
            .listItem(marker: .ordinal(3), depth: 0), .listItem(marker: .bullet, depth: 1), .paragraph,
        ])
        #expect(doc.blocks.map(\.text) == ["one", "two x", "a", "b", "c", "d", "inner", "after"])
        #expect(plain(doc).hasPrefix("• one\n• two x\n1. a\n2. b\nc\n3. d\n• inner\nafter"))
    }

    /// New with the port, not in Mushaf: the closure, not the parser, decides how an ordered number reads.
    @Test func plainTextFormatsOrderedNumbersThroughTheClosure() {
        let doc = Doc(html: "<ol><li>a</li><li>b</li></ol>")
        #expect(doc.plainText(number: { $0 == 1 ? "one" : "two" }) == "one. a\ntwo. b")
    }

    @Test func lineBreaksWhitespaceAndEntities() {
        let doc = Doc(html: "<p>  first\n line<br>second &amp; &lt;third&gt;  </p>\n\n<p>\tnext</p>")
        #expect(doc.blocks.map(\.text) == ["first line\nsecond & <third>", "next"])
    }

    /// The superscript is a chrome face at 0.68 of the body size, so no registered face is needed.
    @Test func superscriptIsRaisedAndSmaller() throws {
        let doc = Doc(html: "<p>note<sup>1</sup></p>")
        #expect(doc.blocks[0].runs.last == .init(text: "1", style: .superscript))
        let text = Doc.attributedString(doc.blocks[0], fontSize: 20, direction: .ltr, faces: .unavailable)
        let sup = try #require(text.runs.last)
        #expect(String(text[sup.range].characters) == "1")
        #expect(sup.baselineOffset == 7)
        #expect(sup.font == QuranFaces.chromeFont(size: 20 * 0.68, weight: .regular))
    }

    @Test func boldAndHeadingsUseSemibold() throws {
        let doc = Doc(html: "<h2>H</h2><p>a <b>b</b></p>")
        let heading = Doc.attributedString(doc.blocks[0], fontSize: 10, direction: .ltr, faces: .unavailable)
        #expect(heading.runs.first?.font == QuranFaces.chromeFont(size: Doc.fontSize(for: .heading(level: 2), base: 10), weight: .semibold))
        let body = Doc.attributedString(doc.blocks[1], fontSize: 10, direction: .ltr, faces: .unavailable)
        #expect(body.runs.map(\.font) == [QuranFaces.chromeFont(size: 10, weight: .regular), QuranFaces.chromeFont(size: 10, weight: .semibold)])
    }

    /// An Arabic quote inside English: isolated right-to-left and set in KFGQPC Hafs.
    @Test func arabicRunInsideEnglish() throws {
        #expect(faces.contains(.ayahText))
        let doc = Doc(html: #"<p>He said <span lang="ar">بِسۡمِ ٱللَّهِ</span>, then <i>left</i>.</p>"#)
        let block = doc.blocks[0]
        #expect(!block.isArabic)
        #expect(block.runs[1].style == .arabic)
        #expect(scalars(block.runs[1].text) == scalars("بِسۡمِ ٱللَّهِ"))
        let text = Doc.attributedString(block, fontSize: 17, direction: .ltr, faces: faces)
        #expect(scalars(String(text.characters)) == scalars("He said \u{2067}بِسۡمِ ٱللَّهِ\u{2069}, then left."))
        let arabic = try #require(text.runs.first { String(text[$0.range].characters).contains("ٱللَّهِ") })
        #expect(arabic.font == faces.font(.ayahText, size: 17 * 1.12))
        let english = try #require(text.runs.first)
        #expect(english.font == QuranFaces.chromeFont(size: 17, weight: .regular))
    }

    /// A whole Arabic block inside English reads right-to-left on its own: no isolates needed.
    @Test func arabicBlockInsideEnglish() {
        let doc = Doc(html: #"<p>English.</p><div lang="ar"><p>قال تعالى</p></div><p>More.</p>"#)
        #expect(doc.blocks.map(\.isArabic) == [false, true, false])
        let text = Doc.attributedString(doc.blocks[1], fontSize: 17, direction: .ltr, faces: faces)
        #expect(scalars(String(text.characters)) == scalars("قال تعالى"))
        #expect(text.runs.first?.font == faces.font(.ayahText, size: 17 * 1.12))
    }

    /// Muyassar is right-to-left throughout: its prose keeps the system font, only Quran
    /// quotes use Hafs, and nothing is isolated.
    @Test func quranQuoteInsideArabicTafsir() throws {
        let doc = Doc(html: #"<div lang="ar"><p>باسم الله <span lang="ar" class="quran">﴿ٱلرَّحۡمَٰنِ﴾</span> ذي الرحمة</p></div>"#)
        let block = doc.blocks[0]
        #expect(block.isArabic)
        #expect(block.runs.map(\.style) == [.arabic, [.arabic, .quran], .arabic])
        let text = Doc.attributedString(block, fontSize: 17, direction: .rtl, faces: faces)
        #expect(scalars(String(text.characters)) == scalars("باسم الله ﴿ٱلرَّحۡمَٰنِ﴾ ذي الرحمة"))
        #expect(text.runs.map(\.font) == [
            QuranFaces.chromeFont(size: 17, weight: .regular), faces.font(.ayahText, size: 17), QuranFaces.chromeFont(size: 17, weight: .regular),
        ])
    }

    @Test func toleratesWhatThePipelineNeverWrites() {
        let doc = Doc(html: "<p>a <u>b</u> c</p><table>d</table>e < f")
        #expect(doc.blocks.map(\.text) == ["a b c", "de < f"])   // a '<' that opens no tag stays text
    }

    /// The parser returns the same document off the main actor as the synchronous initialiser does on it.
    @Test func parsedMatchesTheSynchronousParse() async {
        let html = #"<h3>Title</h3><ul><li>one <b>two</b></li></ul><p>a &amp; <i>b</i></p>"#
        let off = await Doc.parsed(html: html)
        #expect(off == Doc(html: html))
        #expect(off.blocks.count == 3)
    }

    /// The real entries: Muyassar 1:1 (surah introduction headings and Quran quotes) and the
    /// English 1:1 (plain text) and 3:3 (one <p>).
    ///
    /// Guarded on the full data: Muyassar and En-Mukhtasar are not in a public clone, which bundles
    /// Tafsir al-Jalalayn alone, so the assertions have no pack to read there.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func realEntries() async throws {
        let repository = TafsirRepository(store: QuranTestData.bundledPacks, index: QuranTestData.index())
        let muyassar = try #require(try await repository.tafsir(for: VerseReference(surah: 1, verse: 1), pack: ContentPackID("ar-muyassar")))
        let doc = Doc(html: muyassar.html)
        #expect(doc.blocks.map(\.kind) == [.heading(level: 3), .paragraph, .heading(level: 3), .paragraph, .paragraph, .heading(level: 3), .paragraph])
        #expect(scalars(doc.blocks[0].text) == scalars("تسمية السورة"))
        #expect(doc.blocks.allSatisfy { $0.isArabic })
        let quotes = doc.blocks[6].runs.filter { $0.style.contains(.quran) }.map(\.text)
        // Mushaf's assertion, with the meaning it had there: the same words, compared as strings.
        // Not by scalars: these literals are in canonical order (fatha, then shadda) and the pack
        // stores the shadda first, so the two are equal as text and differ as scalar sequences.
        #expect(quotes == ["﴿\u{200A}ٱللَّهِ﴾", "﴿ٱلرَّحۡمَٰنِ﴾", "﴿ٱلرَّحِيمِ﴾"])
        // The stricter check, against the data and not a literal: every quote comes out of the
        // parser scalar for scalar as the pack's HTML holds it, so nothing was normalised on the way.
        let stored = muyassar.html.matches(of: /﴿[^﴾]*﴾/).map { scalars(String($0.output)) }
        #expect(quotes.map(scalars) == stored)

        let english = try #require(try await repository.tafsir(for: VerseReference(surah: 1, verse: 1), pack: ContentPackID("en-mukhtasar")))
        let englishDoc = Doc(html: english.html)
        #expect(englishDoc.blocks.count == 1 && englishDoc.blocks[0].kind == .paragraph)
        #expect(englishDoc.blocks[0].text.unicodeScalars.starts(with: "I begin by calling on Allah, Who is Ar-Raḥmān".unicodeScalars))
        let wrapped = try #require(try await repository.tafsir(for: VerseReference(surah: 3, verse: 3), pack: ContentPackID("en-mukhtasar")))
        #expect(Doc(html: wrapped.html).blocks.count == 1)
    }
}
