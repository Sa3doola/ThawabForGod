//
//  MarginMarkerTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The juz, hizb, quarter and sajdah labels in a printed page's margin.
///
/// A marker sits on the line of the printed page where its ayah's first word (or its ۩) is drawn,
/// so every test here needs the printed layout and is guarded to the full build (T4). The Tanzil
/// build has no pages, and therefore no margin.
struct MarginMarkerTests {

    /// The full database's corpus, which is the only one with a margin to test.
    static func loadedCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
    }

    /// Juz 11 begins mid-page at 9:93 (۞ إِنَّمَا, line 13).
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func page201ShowsTheJuzStartOnItsLine() async throws {
        let corpus = try await Self.loadedCorpus()
        #expect(corpus.marginMarkers(page: 201) == [
            MushafMarginMarker(line: 13, ayah: VerseReference(surah: 9, verse: 93), kind: .juz(11)),
        ])
    }

    /// The sajdah of 17:109 (خُشُوعٗا ۩, line 6). Al-Kahf begins on the page but no quarter does.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func page293ShowsTheSajdah() async throws {
        let corpus = try await Self.loadedCorpus()
        #expect(corpus.marginMarkers(page: 293) == [
            MushafMarginMarker(line: 6, ayah: VerseReference(surah: 17, verse: 109), kind: .sajdah),
        ])
    }

    /// 240 quarter starts (30 juz, 30 more hizb, 180 quarters) and 15 sajdahs, each on a line
    /// of the page where its ayah's first word (or its ۩) is printed.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func everyDivisionAndSajdahHasOneMarker() async throws {
        let corpus = try await Self.loadedCorpus()
        let all = corpus.pages.flatMap { page in corpus.marginMarkers(page: page.number).map { (page, $0) } }
        #expect(all.count == 255)
        #expect(all.filter { isJuz($0.1.kind) }.count == 30)
        #expect(all.filter { isHizb($0.1.kind) }.count == 30)
        #expect(all.filter { isQuarter($0.1.kind) }.count == 180)
        #expect(all.filter { $0.1.kind == .sajdah }.count == 15)
        for (page, marker) in all {
            let line = try #require(page.lines.first { $0.number == marker.line }, "p\(page.number)")
            #expect(line.segments.contains { $0.reference == marker.ayah }, "p\(page.number) \(marker)")
        }
        // Juz labels sit on the standard juz first pages.
        let juzPages = all.compactMap { (page, marker) -> (Int, Int)? in
            if case .juz(let number) = marker.kind { return (number, page.number) }
            return nil
        }
        #expect(juzPages.map(\.0) == Array(1...30))
        #expect(juzPages.first { $0.0 == 11 }?.1 == 201)
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func quarterNumbering() async throws {
        let corpus = try await Self.loadedCorpus()
        let kinds = corpus.pages.flatMap { corpus.marginMarkers(page: $0.number) }.map(\.kind)
        // Hizb 2 (second half of juz 1) and its quarters come in order.
        #expect(kinds.prefix(8) == [.juz(1), .quarter(1, hizb: 1), .quarter(2, hizb: 1), .quarter(3, hizb: 1),
                                    .hizb(2), .quarter(1, hizb: 2), .quarter(2, hizb: 2), .quarter(3, hizb: 2)])
    }

    private func isJuz(_ kind: MushafMarginMarker.Kind) -> Bool {
        if case .juz = kind { return true }
        return false
    }

    private func isHizb(_ kind: MushafMarginMarker.Kind) -> Bool {
        if case .hizb = kind { return true }
        return false
    }

    private func isQuarter(_ kind: MushafMarginMarker.Kind) -> Bool {
        if case .quarter = kind { return true }
        return false
    }
}
