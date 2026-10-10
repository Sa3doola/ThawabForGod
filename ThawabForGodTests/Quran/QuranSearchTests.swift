//
//  QuranSearchTests.swift
//  ThawabForGodTests
//

import ArabicText
import Foundation
import GRDB
import Testing
@testable import ThawabForGod

// Ported from Mushaf's `SearchTests`. The folding, FTS-syntax, highlighting and grouping cases are
// pure and run everywhere. The repository cases run on every Quran database that is bundled (the
// public Tanzil build always, the QUL build when it was built), and only the cases that pin a count
// or an exact list from one build, or that need a translation pack, are guarded.

/// The query folding: what a typed query becomes, and that Arabic forms which should fold together
/// do. Pure, so it needs no database and no guard. The folding rule must match the one the index was
/// built with, which is what `QuranSearchRepositoryTests` checks against the shipped data.
struct QuranSearchQueryTests {

    @Test(arguments: [
        ("ٱلرَّحۡمَٰنِ", "الرحمن"),      // Hafs spelling: wasla, tashkeel, dagger alef
        ("إِبۡرَٰهِيمَ", "ابرهيم"),        // hamza below
        ("أحمد", "احمد"), ("آمنوا", "امنوا"), ("إله", "اله"),   // hamza and madda forms of alef
        ("رحمة", "رحمه"),                 // ta marbuta
        ("موسى", "موسي"),                 // alef maqsura
        ("مؤمن", "مومن"), ("شيئ", "شيي"), // hamza on waw and on ya
        ("الرحــــمن", "الرحمن"),          // tatweel
        ("قَالَ", "قال"),
    ])
    func arabicFormsFoldTogether(_ written: String, _ plain: String) {
        #expect(QuranSearchQuery(written, scope: .quran) == QuranSearchQuery(plain, scope: .quran), "\(written)")
    }

    @Test func latinQueriesIgnoreCaseAndDiacritics() {
        #expect(QuranSearchQuery("MOSES", scope: .translations)?.tokens == ["moses"])
        #expect(QuranSearchQuery("Allāh", scope: .translations)?.tokens == ["allah"])
        #expect(QuranSearchQuery("Ever-Living", scope: .translations)?.tokens == ["ever", "living"])
    }

    @Test(arguments: ["", "   ", "ا", "a", "!!", "؟", "ـ", "َ"])
    func tooShortQueriesAreNotRun(_ text: String) {
        #expect(QuranSearchQuery(text, scope: .quran) == nil, "\(text)")
        #expect(QuranSearchQuery(text, scope: .translations) == nil, "\(text)")
    }

    @Test func twoLettersAreEnoughInArabic() {
        #expect(QuranSearchQuery("قل", scope: .quran) != nil)
    }

    /// Quotes and FTS5 operators typed by the reader are words, never syntax.
    @Test func ftsSyntaxCannotLeakIn() throws {
        let query = try #require(QuranSearchQuery(#"mercy" OR "x NEAR(a b) *"#, scope: .translations))
        #expect(query.ftsExpression == #""mercy" "or" "x" "near" "a" "b"*"#)
    }

    // MARK: Highlighting (literal strings, no database)

    @Test func arabicHighlightMarksTheHafsWord() throws {
        let text = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
        let query = try #require(QuranSearchQuery("الرحمن", scope: .quran))
        let ranges = QuranSearchHighlight.arabicRanges(in: text, query: query)
        #expect(ranges.map { String(text[$0]) } == ["ٱلرَّحۡمَٰنِ"])
        // The prefix matches while typing: "الرح" marks both.
        let typing = try #require(QuranSearchQuery("الرح", scope: .quran))
        #expect(QuranSearchHighlight.arabicRanges(in: text, query: typing).count == 2)
    }

    /// A Hafs word with an attached particle is highlighted (للرحمن in 19:26); a short query word is
    /// not matched inside فلما.
    @Test func arabicHighlightMarksAttachedForms() throws {
        let text = "فَقُولِيٓ إِنِّي نَذَرۡتُ لِلرَّحۡمَٰنِ صَوۡمٗا"
        let query = try #require(QuranSearchQuery("الرحمن", scope: .quran))
        #expect(QuranSearchHighlight.arabicRanges(in: text, query: query).map { String(text[$0]) } == ["لِلرَّحۡمَٰنِ"])
        let short = try #require(QuranSearchQuery("ما", scope: .quran))
        #expect(QuranSearchHighlight.arabicRanges(in: "فَلَمَّا جَآءَهُم", query: short).isEmpty)
    }

    /// The Imlaei spelling finds 2:3, whose Hafs spelling differs (ٱلصَّلَوٰةَ): the result is shown
    /// without a highlight rather than with an altered text. The finding half is in
    /// `QuranSearchRepositoryTests`.
    @Test func spellingDifferencesShowNoHighlight() throws {
        let query = try #require(QuranSearchQuery("الصلاة", scope: .quran))
        #expect(QuranSearchHighlight.arabicRanges(in: "ٱلَّذِينَ يُؤۡمِنُونَ بِٱلۡغَيۡبِ وَيُقِيمُونَ ٱلصَّلَوٰةَ", query: query).isEmpty)
    }

    @Test func translationHighlight() throws {
        let text = "the Entirely Merciful, the Especially Merciful. Mercy!"
        let query = try #require(QuranSearchQuery("merciful", scope: .translations))
        #expect(QuranSearchHighlight.latinRanges(in: text, query: query).map { String(text[$0]) } == ["Merciful", "Merciful"])
        let exact = try #require(QuranSearchQuery("mercy the", scope: .translations))
        #expect(QuranSearchHighlight.latinRanges(in: text, query: exact).map { String(text[$0]) } == ["the", "the", "Mercy"])
    }
}

/// Search against the shipped Quran databases. Every case that does not pin a number or an exact
/// list runs on each bundled database; the Mushaf counts and orderings are guarded because they were
/// measured on the printed build only. The translation cases need the Saheeh International pack,
/// which exists only where the full data was built.
struct QuranSearchRepositoryTests {

    static let saheeh = ContentPackID("en-sahih-international")

    /// Every Quran database this build bundles: the public one always, the full one when built.
    static var databases: [QuranDatabase] {
        [QuranTestData.publicDatabase] + (QuranTestData.hasFullData ? [QuranTestData.fullDatabase] : [])
    }

    /// The search repository over one database and the bundled packs.
    static func repository(_ database: QuranDatabase = QuranTestData.preferredDatabase) -> QuranSearchRepository {
        QuranSearchRepository(quran: database.corpus, store: QuranTestData.bundledPacks, index: QuranTestData.index(database))
    }

    /// Exact matches first, then those found through attached particles.
    static func quran(_ text: String, in database: QuranDatabase = QuranTestData.preferredDatabase) async throws -> [VerseReference] {
        try await quranResult(text, in: database).ranked
    }

    static func quranResult(_ text: String, in database: QuranDatabase = QuranTestData.preferredDatabase) async throws -> QuranSearchResult {
        try await repository(database).searchQuran(try #require(QuranSearchQuery(text, scope: .quran)))
    }

    static func translations(_ text: String) async throws -> [TranslationText] {
        try await repository().searchTranslations(try #require(QuranSearchQuery(text, scope: .translations)), packs: [saheeh])
    }

    // MARK: Folding reaches the index

    @Test func foldedFormsFindTheSameAyahs() async throws {
        for database in Self.databases {
            let plain = try await Self.quran("الرحمن", in: database)
            #expect(try await Self.quran("ٱلرَّحۡمَٰنِ", in: database) == plain, "\(database.resourceName)")
            #expect(try await Self.quran("الرّحمٰن", in: database) == plain, "\(database.resourceName)")
            #expect(try await Self.quran("ابرهيم", in: database) == Self.quran("إبرٰهيم", in: database), "\(database.resourceName)")
        }
    }

    /// The index is over the imla'i text folded by the same rule as the query. Each database is
    /// scanned word by word and must agree with FTS, for the exact matches and for the matches
    /// through stems.
    @Test(arguments: ["الرحمن", "قال", "الصلاه"])
    func ftsAgreesWithAScan(_ text: String) async throws {
        let query = try #require(QuranSearchQuery(text, scope: .quran))
        for database in Self.databases {
            let rows = try await database.corpus.reader().read { db in
                try Row.fetchAll(db, sql: "SELECT surah, ayah, text_imlaei FROM ayah ORDER BY id").map { row -> (Int, Int, String) in (row[0], row[1], row[2]) }
            }
            let scanned = rows.compactMap { row -> VerseReference? in
                let words = QuranSearchQuery.words(ArabicNormalizer.normalize(row.2))
                // Every query word must be present (the last as a prefix).
                let allPresent = query.tokens.enumerated().allSatisfy { index, token in
                    words.contains { $0 == token || (index == query.tokens.count - 1 && $0.hasPrefix(token)) }
                }
                return allPresent ? VerseReference(surah: row.0, verse: row.1) : nil
            }
            // The same scan, also accepting a stem of a word (ArabicPrefixStemmer).
            let withStems = rows.compactMap { row -> VerseReference? in
                let words = QuranSearchQuery.words(ArabicNormalizer.normalize(row.2))
                let allPresent = query.tokens.enumerated().allSatisfy { index, token in
                    let forms = words + (QuranSearchQuery.usesStems(token) ? words.flatMap(ArabicPrefixStemmer.stems(of:)) : [])
                    return forms.contains { $0 == token || (index == query.tokens.count - 1 && $0.hasPrefix(token)) }
                }
                return allPresent ? VerseReference(surah: row.0, verse: row.1) : nil
            }
            let result = try await Self.repository(database).searchQuran(query)
            #expect(result.exact == scanned, "\(text) in \(database.resourceName)")
            #expect((result.exact + result.attached).sorted() == withStems, "\(text) in \(database.resourceName)")
        }
    }

    /// The Imlaei spelling finds 2:3, whose Hafs spelling differs; see `spellingDifferencesShowNoHighlight`.
    @Test func imlaeiSpellingFindsTheHafsDifferenceVerse() async throws {
        for database in Self.databases {
            #expect(try await Self.quran("الصلاة", in: database).contains(VerseReference(surah: 2, verse: 3)), "\(database.resourceName)")
        }
    }

    // MARK: Ordering

    @Test func resultsAreInMushafOrderAndAttachedAfterExact() async throws {
        for database in Self.databases {
            let result = try await Self.quranResult("الرحمن", in: database)
            let ayahs = result.exact
            #expect(ayahs == ayahs.sorted(), "\(database.resourceName)")
            #expect(result.attached == result.attached.sorted(), "\(database.resourceName)")
            #expect(ayahs.first == VerseReference(surah: 1, verse: 1), "\(database.resourceName)")
            #expect(result.ranked.prefix(result.exact.count).elementsEqual(result.exact), "\(database.resourceName)")
            #expect(Set(result.exact).isDisjoint(with: result.attached), "\(database.resourceName)")
        }
    }

    /// Phase 6.0: 19:26 has للرحمن; it is found, after the exact matches. Mushaf's printed build only.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func attachedParticlesAreFoundAndRankedAfter() async throws {
        let result = try await Self.quranResult("الرحمن", in: QuranTestData.fullDatabase)
        #expect(result.attached.contains(VerseReference(surah: 19, verse: 26)))
        #expect(!result.exact.contains(VerseReference(surah: 19, verse: 26)))
    }

    /// "رحمن" without the article: stems keep the article (للرحمن → الرحمن), so it finds only the
    /// words that start with رحمن (رحمناهم 23:75, رحمنا 67:28), as before.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func bareStemWithoutArticle() async throws {
        let result = try await Self.quranResult("رحمن", in: QuranTestData.fullDatabase)
        #expect(result.exact == [VerseReference(surah: 23, verse: 75), VerseReference(surah: 67, verse: 28)])
        #expect(result.attached.isEmpty)
    }

    // MARK: Hit counts (measured on the printed build)

    /// Counts in the Mushaf data (quran.sqlite schema 3, Saheeh International v1). The last word
    /// matches as a prefix: "قال" also finds قالوا, قالت. `exact` is the count before Phase 6.0
    /// (own forms only); `all` adds the forms with attached particles (وقال, للرحمن, بالله).
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason), arguments: [
        ("الرحمن", 45, 56), ("الله", 1573, 1737), ("قال", 604, 788), ("الكتاب", 151, 162),
        ("بسم الله", 3, 3), ("موسى", 124, 131),
    ])
    func knownArabicCounts(_ text: String, _ exact: Int, _ all: Int) async throws {
        let result = try await Self.quranResult(text, in: QuranTestData.fullDatabase)
        #expect(result.exact.count == exact, "\(text)")
        #expect(result.count == all, "\(text)")
    }

    /// Short words never match through stems: ما and لا find exactly what they found before.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason), arguments: [("ما", 994), ("لا", 940)])
    func shortWordsGainNoFalseHits(_ text: String, _ count: Int) async throws {
        let result = try await Self.quranResult(text, in: QuranTestData.fullDatabase)
        #expect(result.attached.isEmpty, "\(text)")
        #expect(result.exact.count == count, "\(text)")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func resultsAreGroupedBySurah() async throws {
        let ayahs = try await Self.quranResult("الرحمن", in: QuranTestData.fullDatabase).exact
        let groups = SurahGroup.groups(ayahs) { $0 }
        #expect(groups.map(\.surah) == groups.map(\.surah).sorted())
        #expect(groups.reduce(0) { $0 + $1.items.count } == 45)
        #expect(groups.first { $0.surah == 19 }?.items.count == 11, "Maryam")
    }

    // MARK: Translations (Saheeh International pack)

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason), arguments: [("mercy", 144), ("Moses", 167), ("Ayat", 0)])
    func knownTranslationCounts(_ text: String, _ count: Int) async throws {
        #expect(try await Self.translations(text).count == count, "\(text)")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func twoLettersAreEnoughInTranslations() async throws {
        #expect(try await Self.translations("of").count > 1000)
    }

    /// The translation search takes only translation packs: a tafsir id returns nothing.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func ftsSyntaxCannotLeakIntoTranslations() async throws {
        let query = try #require(QuranSearchQuery(#"mercy" OR "x NEAR(a b) *"#, scope: .translations))
        _ = try await Self.repository().searchTranslations(query, packs: [Self.saheeh])
        #expect(try await Self.repository().searchTranslations(query, packs: [ContentPackID("ar-muyassar")]).isEmpty, "a tafsir is not a translation")
    }
}

/// How long a query takes to run and group. Mushaf's target is 100 ms per query, warm, on the
/// simulator — but this suite runs alongside nine hundred others in parallel, where one run measured
/// a 122 ms median with an 862 ms outlier during the M3 port. So the assertion is a ceiling five
/// times the target, which catches a query that stopped using the index (seconds, not tens of
/// milliseconds) without failing on a busy runner; the target itself is measured by the
/// performance runs (M4, M8). The Arabic cases run everywhere; the translation cases need the
/// Saheeh International pack.
struct QuranSearchTimingTests {

    /// Five times Mushaf's 100 ms target; see above.
    static let ceiling: Double = 500

    /// Six runs of one query and its grouping; the first is the cold run.
    static func timings(_ text: String, scope: QuranSearchScope) async throws -> [Double] {
        let query = try #require(QuranSearchQuery(text, scope: scope))
        let repository = QuranSearchRepositoryTests.repository()
        var times: [Double] = []
        for _ in 0..<6 {
            let start = ContinuousClock.now
            if scope == .quran {
                _ = SurahGroup.groups(try await repository.searchQuran(query).ranked) { $0 }
            } else {
                _ = SurahGroup.groups(try await repository.searchTranslations(query, packs: [QuranSearchRepositoryTests.saheeh])) { $0.ayah }
            }
            times.append((ContinuousClock.now - start) / .milliseconds(1))
        }
        return times
    }

    @Test(arguments: ["الرحمن", "قال"])
    func arabicQueriesAreFast(_ text: String) async throws {
        let times = try await Self.timings(text, scope: .quran)
        let warm = times.dropFirst().sorted()
        #expect(warm[warm.count / 2] < Self.ceiling, "\(text): \(warm)")
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason), arguments: ["mercy", "Moses"])
    func translationQueriesAreFast(_ text: String) async throws {
        let times = try await Self.timings(text, scope: .translations)
        let warm = times.dropFirst().sorted()
        #expect(warm[warm.count / 2] < Self.ceiling, "\(text): \(warm)")
    }
}
