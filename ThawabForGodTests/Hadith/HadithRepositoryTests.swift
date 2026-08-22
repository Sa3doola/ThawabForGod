//
//  HadithRepositoryTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Reads the hadith corpus that actually ships.
///
/// The weight `QuranRepositoryTests` and `TafsirRepositoryTests` carry, for the same reason: the
/// shape is fixed and checkable, and a build that disagrees with any of it is wrong in a way no
/// amount of reading the screen would reveal. Two collections, 154 kitab, 14,940 narrations, and
/// every one of them Arabic.
struct HadithRepositoryTests {

    private let repository = HadithRepository(database: CorpusDatabase(name: "hadith"))

    private let bukhari = "bukhari"
    private let muslim = "muslim"

    // MARK: The collections

    @Test func theBundleCarriesTheTwoSahihs() async throws {
        let collections = try await repository.collections()

        #expect(collections.map(\.id) == [bukhari, muslim])
    }

    /// Ordered by the corpus's own `ordinal`, which is neither alphabetical order in Arabic nor
    /// in English. Bukhari before Muslim is how these two are always listed, and it is the one
    /// thing about this list a reader would notice being wrong.
    @Test func bukhariComesFirst() async throws {
        let first = try #require(try await repository.collections().first)

        #expect(first.arabicName == "صحيح البخاري")
        #expect(first.englishName == "Sahih al-Bukhari")
        #expect(first.arabicAuthor.contains("البخاري"))
    }

    /// The counts are computed by the query rather than stored, so this asserts the join as much
    /// as the corpus: a collection counting the other one's narrations would show up here.
    @Test func eachCollectionKnowsHowLargeItIs() async throws {
        let collections = try await repository.collections()

        #expect(collections[0].bookCount == 97)
        #expect(collections[0].hadithCount == 7580)
        #expect(collections[1].bookCount == 57)
        #expect(collections[1].hadithCount == 7360)
    }

    // MARK: The divisions

    @Test func bukhariOpensWithTheBookOfRevelation() async throws {
        let books = try await repository.books(inCollection: bukhari)
        let first = try #require(books.first)

        #expect(books.count == 97)
        #expect(first.number == 1)
        #expect(first.arabicTitle == "كتاب بدء الوحى")
        #expect(first.englishTitle == "Revelation")
        #expect(first.hadithCount == 7)
    }

    /// **Zero is a real kitab number.** Sahih Muslim's introduction is numbered 0, and a build
    /// that treated the number as a one-based index — or as missing — would drop it silently.
    @Test func muslimsIntroductionIsKitabZero() async throws {
        let books = try await repository.books(inCollection: muslim)
        let first = try #require(books.first)

        #expect(first.number == 0)
        #expect(first.arabicTitle == "المقدمة")
    }

    /// No division may be a row the reader taps to reach an empty screen. The build refuses to
    /// write one; this is the check on the other side of the file.
    @Test func everyKitabHasNarrationsInIt() async throws {
        for collection in try await repository.collections() {
            let books = try await repository.books(inCollection: collection.id)

            #expect(books.allSatisfy { $0.hadithCount > 0 })
        }
    }

    @Test func anUnknownCollectionHasNoDivisions() async throws {
        #expect(try await repository.books(inCollection: "tirmidhi").isEmpty)
    }

    @Test func aDivisionCanBeFetchedOnItsOwn() async throws {
        let book = try #require(
            try await repository.book(BookReference(collection: bukhari, number: 97))
        )

        #expect(book.arabicTitle == "كتاب التوحيد")
    }

    @Test func aDivisionTheCorpusLacksIsNil() async throws {
        let book = try await repository.book(BookReference(collection: bukhari, number: 98))

        #expect(book == nil)
    }

    // MARK: The narrations

    /// One word rather than the whole phrase, and deliberately one with no shadda in it.
    ///
    /// Arabic diacritics are combining marks with equal combining classes, so a shadda and a
    /// kasra on the same letter can be stored in either order and mean the same thing. Swift
    /// compares strings under canonical equivalence and would match either, but a literal typed
    /// here in the other order is a difference no diff would show and no reader would spot — so
    /// the assertion avoids the question instead of relying on the answer.
    @Test func theFirstHadithOfBukhariIsTheOneAboutIntentions() async throws {
        let hadiths = try await repository.hadiths(
            inBook: BookReference(collection: bukhari, number: 1)
        )
        let first = try #require(hadiths.first)

        #expect(hadiths.count == 7)
        #expect(first.reference.first == 1)
        #expect(first.text.contains("الْأَعْمَالُ"))
    }

    /// **The licensing invariant, as a test.** The two Sahihs are public domain by age; every
    /// English translation of them belongs to a living translator, and none is licensed to this
    /// project. A narration carrying Latin letters would mean a translation had been bundled —
    /// so this fails on the day someone adds one without settling the licence first.
    ///
    /// Sampled rather than exhaustive: reading all 14,940 narrations to scan them would make a
    /// unit test a disk benchmark. Two whole kitab, one from each collection, is enough to catch
    /// a corpus built from the wrong column.
    @Test(arguments: [("bukhari", 1), ("muslim", 1)])
    func noNarrationCarriesATranslation(collection: String, book: Int) async throws {
        let hadiths = try await repository.hadiths(
            inBook: BookReference(collection: collection, number: book)
        )

        #expect(!hadiths.isEmpty)
        for hadith in hadiths {
            // Latin *letters*, not ASCII: the corpus punctuates with ordinary quotes and colons,
            // which are ASCII and carry no translation with them.
            #expect(!hadith.text.contains { $0.isASCII && $0.isLetter })
        }
    }

    /// A few hundred narrations are published under several consecutive numbers at once. The
    /// corpus stores the span so that a reader arriving with any number in it lands on the text
    /// rather than on nothing — see `HadithReference`.
    @Test func aGroupedNarrationCarriesEveryNumberItIsCitedBy() async throws {
        let hadiths = try await repository.hadiths(
            inBook: BookReference(collection: bukhari, number: 76)
        )
        let grouped = try #require(hadiths.first { $0.reference.first == 5709 })

        #expect(grouped.reference.last == 5712)
        #expect(grouped.reference.isSpan)
        #expect(grouped.reference.covers(5711))
    }

    /// Almost none of them are spans, which is what makes the span worth a type rather than a
    /// special case: the common shape has to stay simple.
    @Test func anOrdinaryNarrationIsOneNumber() async throws {
        let hadiths = try await repository.hadiths(
            inBook: BookReference(collection: bukhari, number: 1)
        )
        let first = try #require(hadiths.first)

        #expect(!first.reference.isSpan)
        #expect(first.reference.first == first.reference.last)
    }

    /// Sahih al-Bukhari prints two narrations under one reference number in twenty-six places.
    /// Both come back, in a stable order — which is what the `part` column is for, and the only
    /// observable consequence of it.
    @Test func twoNarrationsCanShareAReferenceNumber() async throws {
        let hadiths = try await repository.hadiths(
            inBook: BookReference(collection: bukhari, number: 8)
        )
        let sharing = hadiths.filter { $0.reference.first == 402 }

        #expect(sharing.count == 2)
        #expect(sharing[0].text != sharing[1].text)
    }

    @Test func narrationsComeBackInReferenceOrder() async throws {
        let hadiths = try await repository.hadiths(
            inBook: BookReference(collection: muslim, number: 1)
        )
        let numbers = hadiths.map(\.reference.first)

        #expect(!numbers.isEmpty)
        #expect(numbers == numbers.sorted())
    }

    @Test func aDivisionTheCorpusLacksHasNoNarrations() async throws {
        let hadiths = try await repository.hadiths(
            inBook: BookReference(collection: bukhari, number: 98)
        )

        #expect(hadiths.isEmpty)
    }

    // MARK: Search

    private func search(_ text: String, limit: Int = 50) async throws -> HadithSearchResults {
        try await repository.search(ArabicSearchQuery(text), limit: limit)
    }

    /// **The rule this suite exists for.** `ArabicSearchQuery` folds what a reader types and
    /// `build_hadith_db.py` folded what went into the index; a match is only possible where the
    /// two agree. This is that agreement checked against the corpus that actually shipped, rather
    /// than against a fixture that could drift with it.
    ///
    /// Typed the way a reader types — modern spelling, no diacritics — against a corpus stored
    /// fully vowelled. One narration in fifteen thousand matches it.
    @Test func aPhraseTypedWithoutDiacriticsFindsTheNarration() async throws {
        let results = try await search("إنما الأعمال بالنيات")

        #expect(results.total == 1)
        #expect(results.hadiths.first?.collectionID == bukhari)
        #expect(results.hadiths.first?.reference.first == 1)
    }

    /// Searching across both collections, which is what makes the field worth having: a reader
    /// who remembers a phrase rarely remembers which Sahih it is in.
    @Test func resultsCanComeFromEitherCollection() async throws {
        let results = try await search("الايمان")
        let collections = Set(results.hadiths.map(\.collectionID))

        #expect(collections == [bukhari, muslim])
    }

    /// The phrase reading first, the keyword one only if it found nothing. `موسى فرعون` is not a
    /// phrase in either Sahih, but twelve narrations name both — which is what the reader meant.
    @Test func twoWordsThatAreNotAPhraseStillFindTheNarrationsNamingBoth() async throws {
        let results = try await search("موسى فرعون")

        #expect(results.total == 12)
        #expect(!results.hadiths.isEmpty)
    }

    /// The count is of *all* matches, not of the page — so a screen showing fifty can say there
    /// are 1,916, rather than presenting the fifty as the answer.
    @Test func theTotalIsNotCappedByTheLimit() async throws {
        let results = try await search("الرحمن", limit: 10)

        #expect(results.hadiths.count == 10)
        #expect(results.total == 1916)
    }

    /// A tatweel is a typographic stretch, not a letter. Folding drops it rather than treating it
    /// as a word boundary, which is the difference between finding 1,916 narrations and none.
    @Test func aStretchedWordFindsTheSameNarrations() async throws {
        let stretched = try await search("الرحـــمن", limit: 1)
        let plain = try await search("الرحمن", limit: 1)

        #expect(stretched.total == plain.total)
    }

    /// **Nothing a reader types can be read as FTS5 syntax.** A token is letters and digits and
    /// nothing else, so a bare quote is a word boundary rather than an operator — which used to
    /// be a query that threw rather than one that found nothing.
    @Test func quotesAndOperatorsAreJustSeparators() async throws {
        let quoted = try await search("\"الايمان\"", limit: 1)
        let plain = try await search("الايمان", limit: 1)

        #expect(quoted.total == plain.total)
        #expect(try await search("\"الصلاة\" OR *", limit: 1).total == 0)
    }

    @Test func aWordInNeitherSahihFindsNothing() async throws {
        #expect(try await search("زقفونة").isEmpty)
    }

    /// An empty query never reaches the index. `FTS5Query` traps on one, deliberately — `""` is
    /// not valid FTS5 syntax and `"" *` matches every row — so the guard above it is load-bearing
    /// rather than a tidy early return.
    @Test(arguments: ["", "   ", "؟ ، \n"])
    func aQueryWithNoWordsInItSearchesForNothing(text: String) async throws {
        #expect(try await search(text) == .none)
    }
}
