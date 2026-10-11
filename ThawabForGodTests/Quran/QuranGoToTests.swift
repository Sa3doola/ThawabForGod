//
//  QuranGoToTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The Library's go-to field (M5.2, design sections 3.3 and 3.4 and 7): how a typed string is
/// classified, which words and numbers reach a target, what the surah filter leaves, and what
/// submit does with the text.
///
/// The public build has no printed pages, so a page is never a destination there, whatever the
/// text. The guarded cases are the full build's: pages resolve only where the corpus has them.
/// Mushaf's case `goToWords` is split between the public and the guarded cases below.
struct QuranGoToTests {

    private func publicCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)
    }

    private func fullCorpus() async throws -> QuranCorpus {
        try await QuranTestData.repository(QuranTestData.fullDatabase).loadCorpus(style: .madaniV2)
    }

    // MARK: Classifying the text

    @Test(arguments: ["", "  "])
    func aBlankFieldIsEmpty(_ text: String) {
        #expect(QuranGoToInput(text) == .empty, "\(text)")
    }

    /// The Persian (Extended Arabic-Indic) digits are written as escapes, because they look like the
    /// Arabic-Indic ones and the point of the case is that both are read.
    /// `"\u{0661}\u{0668}"` is ١٨, `"\u{06F1}\u{06F8}"` is ۱۸.
    @Test(arguments: ["18", "\u{0661}\u{0668}", "\u{06F1}\u{06F8}"])
    func aNumberInAnyDigitSystemIsANumber(_ text: String) {
        #expect(QuranGoToInput(text) == .number(18), "\(text)")
    }

    @Test(arguments: ["juz 5", "2:255", "2/255", "2 255", "2:", "j", "ju", "juz", "Hizb.", "ال", "الج", "ص"])
    func aCompleteOrPartialAddressIsAnAddress(_ text: String) {
        #expect(QuranGoToInput(text) == .address, "\(text)")
    }

    @Test(arguments: ["kahf", "الكهف", "hij", "zzz"])
    func anythingElseIsAName(_ text: String) {
        #expect(QuranGoToInput(text) == .name, "\(text)")
    }

    // MARK: The surah filter

    @Test func theFilterFindsSurahsByNumberAndName() async throws {
        let corpus = try await publicCorpus()
        let rows = QuranLibraryIndex(corpus: corpus).surahs

        #expect(QuranGoTo.surahs(rows, matching: "").count == 114)
        #expect(QuranGoTo.surahs(rows, matching: "18").map { $0.surah.number } == [18])
        // Arabic-Indic digits, written as escapes: ١٨.
        #expect(QuranGoTo.surahs(rows, matching: "\u{0661}\u{0668}").map { $0.surah.number } == [18])
        #expect(QuranGoTo.surahs(rows, matching: "kahf").map { $0.surah.number } == [18])
        #expect(QuranGoTo.surahs(rows, matching: "Imran").map { $0.surah.number } == [3])
        // Arabic, with or without hamza and tashkeel.
        #expect(QuranGoTo.surahs(rows, matching: "الكهف").map { $0.surah.number } == [18])
        #expect(QuranGoTo.surahs(rows, matching: "الانعام").map { $0.surah.number } == [6])
        #expect(QuranGoTo.surahs(rows, matching: "zzz").isEmpty)
    }

    /// An address in progress narrows nothing: the list stays whole while `juz 5`, `2:255` or `juz`
    /// is typed. (Mushaf's wart, where the filter ran over the address, is not ported.)
    @Test(arguments: ["juz 5", "2:255", "juz"])
    func anAddressInProgressNarrowsNoSurah(_ text: String) async throws {
        let corpus = try await publicCorpus()
        let rows = QuranLibraryIndex(corpus: corpus).surahs

        #expect(QuranGoTo.surahs(rows, matching: text).count == 114, "\(text)")
    }

    // MARK: Words that reach a target

    /// The thirteen cases of Mushaf's `goToWords` that name a juz, a hizb, a surah or an ayah. Each
    /// resolves in the public build, where the corpus has the divisions, the surahs and the ayahs.
    @Test(arguments: [
        ("juz 5", GoToTarget.juz(5)), ("Juz 5", .juz(5)), ("j5", .juz(5)), ("ج ٥", .juz(5)), ("جزء ٥", .juz(5)),
        ("الجزء 30", .juz(30)),
        ("hizb 12", .hizb(12)), ("Hizb. 60", .hizb(60)), ("حزب ١٢", .hizb(12)), ("الحزب ١", .hizb(1)),
        ("surah 18", .surah(18)), ("سورة ١٨", .surah(18)),
        ("2:255", .ayah(VerseReference(surah: 2, verse: 255))),
    ])
    func goToWordsReachTheirTargets(_ text: String, _ target: GoToTarget) async throws {
        #expect(GoToTarget.parse(text, in: try await publicCorpus()) == target, "\(text)")
    }

    /// The four page cases of Mushaf's `goToWords`: a page is a destination only where the corpus has
    /// printed pages.
    @Test(
        .enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason),
        arguments: [("page 50", GoToTarget.page(50)), ("ص ٥٠", .page(50)), ("50", .page(50)), ("٦٠٤", .page(604))]
    )
    func goToPageWordsReachThePagesInTheFullBuild(_ text: String, _ target: GoToTarget) async throws {
        #expect(GoToTarget.parse(text, in: try await fullCorpus()) == target, "\(text)")
    }

    /// Mushaf's `goToRejects`: all ten are `nil` in the public build, which has no page 605 and no
    /// juz 31, and no bare unit word such as `ج` names anything.
    @Test(arguments: ["juz 31", "juz 0", "hizb 61", "page 605", "surah 115", "rub 3", "ج", "foo 3", "2:300", ""])
    func goToRejectsWhatTheCorpusDoesNotHave(_ text: String) async throws {
        #expect(GoToTarget.parse(text, in: try await publicCorpus()) == nil, "\(text)")
    }

    // MARK: Submit

    @Test(arguments: ["page 50", "ص ٥٠", "p50", "الصفحة ٥٠"])
    func aPageIsRefusedWhereThereAreNoPrintedPages(_ text: String) async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(QuranGoTo.resolve(text, corpus: corpus, index: index) == .failed(.pagesUnavailable), "\(text)")
    }

    /// A bare number is a surah in the public build: the parser finds no page for it, and the filter
    /// leaves the surah with that number.
    @Test func aBareNumberGoesToTheSurahWithThatNumber() async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(QuranGoTo.resolve("50", corpus: corpus, index: index) == .go(.surah(50)))
    }

    @Test(arguments: ["115", "0", "juz 31", "2:300", "al", "zzz"])
    func anUnknownTextIsNotFound(_ text: String) async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(QuranGoTo.resolve(text, corpus: corpus, index: index) == .failed(.notFound), "\(text)")
    }

    @Test(arguments: [
        ("juz 5", GoToTarget.juz(5)), ("جزء ٥", .juz(5)), ("hizb 12", .hizb(12)),
        ("2:255", .ayah(VerseReference(surah: 2, verse: 255))), ("surah 18", .surah(18)), ("kahf", .surah(18)),
    ])
    func aKnownAddressOrNameGoesToItsTarget(_ text: String, _ target: GoToTarget) async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(QuranGoTo.resolve(text, corpus: corpus, index: index) == .go(target), "\(text)")
    }

    /// The guarantee the Library rests on: in the public build no number and no "page" plus a number
    /// resolves to a page, for any number from 1 to 700. The failures are collected so one run shows
    /// every offender.
    @Test func noNumberInTheRangeResolvesToAPageInThePublicBuild() async throws {
        let corpus = try await publicCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        var offenders: [String] = []
        for number in 1...700 {
            for text in ["\(number)", "page \(number)"] {
                if case .go(.page) = QuranGoTo.resolve(text, corpus: corpus, index: index) {
                    offenders.append(text)
                }
            }
        }

        #expect(offenders.isEmpty, "resolved to a page: \(offenders)")
    }

    // MARK: Submit with the full build's pages

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theFullBuildResolvesPagesAndRefusesThePageAfterTheLast() async throws {
        let corpus = try await fullCorpus()
        let index = QuranLibraryIndex(corpus: corpus)

        #expect(QuranGoTo.resolve("50", corpus: corpus, index: index) == .go(.page(50)))
        #expect(QuranGoTo.resolve("page 50", corpus: corpus, index: index) == .go(.page(50)))
        #expect(QuranGoTo.resolve("605", corpus: corpus, index: index) == .failed(.notFound))
        #expect(QuranGoTo.resolve("kahf", corpus: corpus, index: index) == .go(.surah(18)))
    }
}
