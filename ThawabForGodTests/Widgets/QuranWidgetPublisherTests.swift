//
//  QuranWidgetPublisherTests.swift
//  ThawabForGodTests
//

import Foundation
import SQLite3
import Testing
@testable import ThawabForGod

/// What the app writes for the two Quran widgets, checked through the App Group's stored snapshot.
///
/// Ported from Mushaf's `WidgetPublisher` tests (M8-B4, section 7). Everything runs against the
/// public (Tanzil) database, which every clone carries; the full database repeat is guarded behind
/// `QuranTestData.hasFullData`. The fakes and `QuranWidgetHarness` here are shared with
/// `QuranWidgetRenderTests`.
@MainActor
struct QuranWidgetPublisherTests {

    // MARK: Exact text

    /// The Arabic is `Ayah.text` byte for byte, for every ayah of every entry: the widget draws the
    /// markers itself, so nothing may have been folded, joined or trimmed on the way in.
    @Test func publishedTextIsTheRepositoryAyahTextByteForByte() async throws {
        let harness = QuranWidgetHarness()
        await harness.publish()
        let snapshot = try #require(harness.snapshot())
        let list = try #require(await AyahOfTheDayList.bundled())
        let expected = try await harness.ayahTexts()

        for entry in snapshot.entries {
            let verses = list.entries[entry.index].verses
            #expect(entry.texts == verses.map { expected[$0] ?? "<missing \($0)>" }, "entry \(entry.index)")
        }
    }

    /// The translation is the pack's own text, one string per ayah of the entry, in order.
    @Test func publishedTranslationIsThePackTextPerAyah() async throws {
        let folder = try QuranWidgetFixtures.translationFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let harness = QuranWidgetHarness(packs: ContentPackStore(directory: folder))
        await harness.publish()
        let snapshot = try #require(harness.snapshot())
        let list = try #require(await AyahOfTheDayList.bundled())
        let surahs = try await harness.repository.surahs(style: MushafStyle.madaniV2.id)

        for entry in snapshot.entries {
            let translation = try #require(entry.translation)
            let verses = list.entries[entry.index].verses
            #expect(translation.packID == "xx-test")
            #expect(translation.nameEnglish == "Test")
            #expect(translation.isRightToLeft == false)
            #expect(translation.texts == verses.map { "Tr \(QuranWidgetHarness.globalNumber($0, surahs: surahs))" })
        }
    }

    /// Names come from the repository when no corpus is open, and are the same names the reader shows.
    @Test func publishedNamesAreTheSurahNames() async throws {
        let harness = QuranWidgetHarness()
        await harness.publish()
        let snapshot = try #require(harness.snapshot())
        let list = try #require(await AyahOfTheDayList.bundled())
        let surahs = try await harness.repository.surahs(style: MushafStyle.madaniV2.id)

        for entry in snapshot.entries {
            let surah = try #require(surahs.first { $0.number == list.entries[entry.index].surah })
            #expect(entry.surahNameArabic == surah.arabicName)
            #expect(entry.surahNameEnglish == surah.englishName)
            #expect(entry.lastVerse == list.entries[entry.index].last)
        }
    }

    // MARK: Coverage

    /// One entry per list entry, its index its position in the list, and no index twice.
    @Test func entriesCoverTheListWithUniqueIndices() async throws {
        let harness = QuranWidgetHarness()
        await harness.publish()
        let snapshot = try #require(harness.snapshot())
        let list = try #require(await AyahOfTheDayList.bundled())

        let indices = snapshot.entries.map(\.index)
        #expect(Set(indices).count == indices.count, "indices are unique")
        #expect(indices.allSatisfy { (0..<list.entries.count).contains($0) })
        #expect(snapshot.listCount == list.entries.count)
        #expect(snapshot.entries.count == list.entries.count, "the public database resolves every entry")
        for entry in snapshot.entries {
            #expect(list.entries[entry.index].first == entry.first)
        }
    }

    /// An entry whose ayahs do not all resolve is left out, and nothing after it moves up to fill the
    /// gap: the widget shows an empty sentence that day rather than another ayah.
    @Test func anEntryWhoseAyahsDoNotResolveIsLeftOutNotShifted() async throws {
        let list = try #require(await AyahOfTheDayList.bundled())
        let dropped = try #require(list.entries.first?.surah)
        let droppedCount = list.entries.filter { $0.surah == dropped }.count
        #expect(droppedCount > 0)

        let harness = QuranWidgetHarness(repository: QuranWidgetDroppingRepository(
            base: QuranTestData.repository(QuranTestData.publicDatabase), dropped: dropped
        ))
        await harness.publish()
        let snapshot = try #require(harness.snapshot())

        #expect(snapshot.entries.count == list.entries.count - droppedCount)
        for entry in snapshot.entries {
            #expect(list.entries[entry.index].surah != dropped)
            let listed = list.entries[entry.index]
            #expect(listed.surah == entry.first.surah && listed.from == entry.first.verse, "entry \(entry.index) keeps its own position")
        }
    }

    // MARK: Writing only what changed

    /// A republish with nothing changed saves nothing and reloads nothing. The check is not by date:
    /// the widget picks the day itself, so an app opened a month later rewrites nothing either.
    @Test func republishingWithNothingChangedWritesAndReloadsNothing() async throws {
        let harness = QuranWidgetHarness()
        await harness.publish()
        let first = harness.store.string(for: .quranWidgetSnapshot)
        #expect(first != nil)
        harness.recorder.clear()

        await harness.publish()
        #expect(harness.store.string(for: .quranWidgetSnapshot) == first)
        #expect(harness.recorder.calls.isEmpty)

        harness.clock.now = harness.clock.now.addingTimeInterval(40 * 24 * 60 * 60)
        await harness.publish()
        #expect(harness.store.string(for: .quranWidgetSnapshot) == first)
        #expect(harness.recorder.calls.isEmpty)
    }

    /// Turning the translation off changes the entries' translations and nothing the Continue
    /// Reading widget shows, so only the ayah kind is reloaded.
    @Test func changingTheTranslationReloadsOnlyTheAyahKind() async throws {
        let folder = try QuranWidgetFixtures.translationFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let harness = QuranWidgetHarness(packs: ContentPackStore(directory: folder))
        harness.userData.recordReadingPosition(VerseReference(surah: 2, verse: 255))
        await harness.userData.flushReadingPosition()
        await harness.publish()
        #expect(harness.snapshot()?.entries.first?.translation != nil)
        harness.recorder.clear()

        harness.settings.setEnabledTranslations([])
        await harness.publish()

        #expect(harness.recorder.calls == [QuranWidgetKind.ayahOfTheDay])
        #expect(harness.snapshot()?.entries.allSatisfy { $0.translation == nil } == true)
    }

    /// A settled reading position updates Continue Reading and leaves the day's entries alone.
    @Test func aSettledPositionReloadsOnlyContinueReading() async throws {
        let harness = QuranWidgetHarness()
        await harness.publish()
        let before = harness.snapshot()
        harness.recorder.clear()

        harness.publisher.positionDidSettle(VerseReference(surah: 2, verse: 255))
        // `positionDidSettle` returns at once and publishes on its own task; wait for that reload.
        for _ in 0..<300 where harness.recorder.calls.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(harness.recorder.calls == [QuranWidgetKind.continueReading])
        let after = try #require(harness.snapshot())
        #expect(after.continueReading?.ayah == VerseReference(surah: 2, verse: 255))
        #expect(after.entries == before?.entries)
    }

    /// The Hafs copy is made once per app version: the first publish installs it and reloads both
    /// kinds, and a later publish of the same version installs nothing.
    @Test func theFontIsCopiedOncePerVersionAndBothKindsReload() async throws {
        let harness = QuranWidgetHarness(hafsURL: URL(fileURLWithPath: "/fonts/KFGQPC-HafsUthmanic.ttf"))
        await harness.publish()

        #expect(await harness.fonts.installs.count == 1)
        #expect(await harness.fonts.installs.first?.isEmpty == false)
        #expect(harness.snapshot()?.fontVersion == QuranWidgetHarness.appVersion)
        #expect(Set(harness.recorder.calls) == [QuranWidgetKind.continueReading, QuranWidgetKind.ayahOfTheDay])

        harness.recorder.clear()
        await harness.publish()
        #expect(await harness.fonts.installs.count == 1)
        #expect(harness.recorder.calls.isEmpty)
    }

    // MARK: Size

    /// The snapshot lives in a `UserDefaults` value, and the widget reads all of it on every entry.
    /// Measured with a translation for every ayah and a reading position, the largest the app writes.
    @Test func theSnapshotStaysUnder512KB() async throws {
        let folder = try QuranWidgetFixtures.translationFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let harness = QuranWidgetHarness(packs: ContentPackStore(directory: folder))
        harness.userData.recordReadingPosition(VerseReference(surah: 2, verse: 255))
        await harness.userData.flushReadingPosition()
        await harness.publish()

        let json = try #require(harness.store.string(for: .quranWidgetSnapshot))
        let bytes = json.utf8.count
        #expect(bytes > 0)
        #expect(bytes < 512 * 1024, "snapshot is \(bytes) bytes")
    }

    // MARK: The bundled list

    @Test func theBundledListDecodesAndKeepsItsSpread() async throws {
        let list = try #require(await AyahOfTheDayList.bundled())
        #expect(list.entries.count >= 60)
        #expect(list.entries.contains { $0.verses.contains(VerseReference(surah: 25, verse: 63)) })
        #expect(!list.entries.contains { $0.verses.contains(VerseReference(surah: 65, verse: 2)) })
    }

    /// Every entry names a surah and a range that exists, so no entry can be silently empty.
    @Test func everyListEntryNamesARealSurahAndRange() async throws {
        let list = try #require(await AyahOfTheDayList.bundled())
        let surahs = try await QuranTestData.repository(QuranTestData.publicDatabase).surahs(style: MushafStyle.madaniV2.id)
        for entry in list.entries {
            let surah = try #require(surahs.first { $0.number == entry.surah }, "surah \(entry.surah)")
            #expect(entry.from >= 1 && entry.from <= entry.last, "\(entry.reference)")
            #expect(entry.last <= surah.ayahCount, "\(entry.reference)")
        }
    }

    // MARK: Full database

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func fullDatabaseRepeatsTheExactTextCheck() async throws {
        let harness = QuranWidgetHarness(database: QuranTestData.fullDatabase, packs: QuranTestData.bundledPacks)
        await harness.publish()
        let snapshot = try #require(harness.snapshot())
        let list = try #require(await AyahOfTheDayList.bundled())
        let expected = try await harness.ayahTexts()
        #expect(snapshot.entries.count == list.entries.count)
        for entry in snapshot.entries {
            #expect(entry.texts == list.entries[entry.index].verses.map { expected[$0] ?? "<missing>" }, "entry \(entry.index)")
        }
    }
}

// MARK: - Fakes and harness (shared with QuranWidgetRenderTests)

/// Records every reload the publisher asks for, in order. Synchronous, as `WidgetRefreshing` is.
nonisolated final class QuranWidgetReloadRecorder: WidgetRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private var reloads: [String] = []

    func reloadAll() {
        lock.withLock { reloads.append("*") }
    }

    func reload(kind: String) {
        lock.withLock { reloads.append(kind) }
    }

    var calls: [String] { lock.withLock { reloads } }

    func clear() { lock.withLock { reloads = [] } }
}

/// Records the font copies asked for and answers `true`, so no file is touched.
actor QuranWidgetFontRecorder: QuranWidgetFontInstalling {
    private(set) var installs: [[URL]] = []

    func install(from sources: [URL]) async -> Bool {
        installs.append(sources)
        return true
    }
}

/// Reading positions and marks, kept nowhere. The publisher reads the reader's position from memory,
/// and these only have to accept the write `flushReadingPosition()` makes.
actor QuranWidgetNoMarks: QuranUserDataRepositoring, QuranReadingPositionRepositoring {
    func marks() async throws -> QuranUserMarks { QuranUserMarks() }
    func setBookmarked(_ isBookmarked: Bool, ayah: VerseReference, at date: Date) async throws {}
    func setNote(_ text: String, ayah: VerseReference, at date: Date) async throws {}
    func setHighlight(_ color: HighlightColor?, ayah: VerseReference, at date: Date) async throws {}
    func removeAllMarks() async throws {}
    func readingPosition() async throws -> QuranReadingPosition? { nil }
    func recordReadingPosition(_ ayah: VerseReference, at date: Date) async throws {}
}

/// A clock the test moves by hand. Only ever read on the main actor.
nonisolated final class QuranWidgetClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

/// A repository that answers every call as the public database does, except that one surah has no
/// ayahs, so its entries cannot resolve.
nonisolated struct QuranWidgetDroppingRepository: QuranRepositoring {
    let base: any QuranRepositoring
    let dropped: Int

    @concurrent func capabilities() async throws -> QuranCapabilities {
        try await base.capabilities()
    }

    @concurrent func loadCorpus(style: MushafStyleID) async throws -> QuranCorpus {
        try await base.loadCorpus(style: style)
    }

    @concurrent func surahs(style: MushafStyleID) async throws -> [Surah] {
        try await base.surahs(style: style)
    }

    @concurrent func page(_ number: Int, style: MushafStyleID) async throws -> MushafPage {
        try await base.page(number, style: style)
    }

    @concurrent func ayahs(surah: Int, style: MushafStyleID) async throws -> [Ayah] {
        if surah == dropped { return [] }
        return try await base.ayahs(surah: surah, style: style)
    }

    @concurrent func pageNumber(for ayah: VerseReference, style: MushafStyleID) async throws -> Int {
        try await base.pageNumber(for: ayah, style: style)
    }

    @concurrent func metadata(style: MushafStyleID) async throws -> QuranMetadata {
        try await base.metadata(style: style)
    }
}

/// Test packs written here: a translation with one line per ayah of the Quran.
nonisolated enum QuranWidgetFixtures {

    /// A folder holding `translation-xx-test.sqlite`, with `Tr <n>` for global ayah `n` (1...6236).
    static func translationFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("QuranWidgetPacks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open(folder.appendingPathComponent("translation-xx-test.sqlite").path, &db) == SQLITE_OK else {
            throw CocoaError(.fileWriteUnknown)
        }
        let sql = """
            CREATE TABLE pack (id TEXT, kind TEXT, language TEXT, name TEXT, name_ar TEXT, author TEXT, author_ar TEXT, direction TEXT, version INT, source_url TEXT, license TEXT);
            CREATE TABLE translation (ayah_id INT PRIMARY KEY, text TEXT, footnotes_json TEXT NULL);
            INSERT INTO pack VALUES ('xx-test', 'translation', 'en', 'Test', 'اختبار', 'Tester', 'مختبر', 'ltr', 1, '', 'test');
            WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 6236)
            INSERT INTO translation (ayah_id, text, footnotes_json) SELECT i, 'Tr ' || i, NULL FROM n;
            """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
        return folder
    }
}

/// The publisher wired to fakes, over one database, with a clock the test controls.
@MainActor
final class QuranWidgetHarness {
    static let appVersion = "test-1.0"
    static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    let repository: any QuranRepositoring
    let store: InMemorySettingsStore
    let clock: QuranWidgetClock
    let settings: QuranReaderSettings
    let reader: QuranReaderViewModel
    let userData: QuranUserDataStore
    let recorder: QuranWidgetReloadRecorder
    let fonts: QuranWidgetFontRecorder
    let publisher: QuranWidgetPublisher

    /// - Parameters:
    ///   - packs: where translations come from; none by default, as in a build with no pack.
    ///   - repository: overrides the database's repository (for the dropped-surah case).
    init(
        database: QuranDatabase = QuranTestData.publicDatabase,
        packs: any ContentPackStoring = ContentPackStore(directory: nil),
        repository: (any QuranRepositoring)? = nil,
        hafsURL: URL? = nil
    ) {
        // Every collaborator is a local first, so no stored property is read before it is set.
        let repository = repository ?? QuranTestData.repository(database)
        let store = InMemorySettingsStore()
        let clock = QuranWidgetClock(QuranWidgetHarness.start)
        let settings = QuranReaderSettings(settingsStore: store)
        let reader = QuranReaderViewModel(repository: repository, settings: settings)
        let positions = QuranWidgetNoMarks()
        let userData = QuranUserDataStore(repository: positions, positions: positions, now: { clock.now })
        let recorder = QuranWidgetReloadRecorder()
        let fonts = QuranWidgetFontRecorder()

        self.repository = repository
        self.store = store
        self.clock = clock
        self.settings = settings
        self.reader = reader
        self.userData = userData
        self.recorder = recorder
        self.fonts = fonts
        publisher = QuranWidgetPublisher(
            repository: repository,
            translations: TranslationRepository(store: packs, index: QuranTestData.index(database)),
            settings: settings,
            reader: reader,
            userData: userData,
            settingsStore: store,
            widgets: recorder,
            fonts: fonts,
            fontURLs: hafsURL.map { [$0] } ?? [],
            appVersion: QuranWidgetHarness.appVersion
        )
    }

    func publish() async {
        await publisher.publish()
    }

    func snapshot() -> QuranWidgetSnapshot? {
        QuranWidgetSnapshot.load(from: store)
    }

    /// Every ayah of the database, by reference, as the repository reads it.
    func ayahTexts() async throws -> [VerseReference: String] {
        var texts: [VerseReference: String] = [:]
        let style = MushafStyle.madaniV2.id
        for surah in try await repository.surahs(style: style) {
            for ayah in try await repository.ayahs(surah: surah.number, style: style) {
                texts[ayah.id] = ayah.text
            }
        }
        return texts
    }

    /// The global ayah number (1...6236) of a reference, as the translation pack numbers them.
    static func globalNumber(_ reference: VerseReference, surahs: [Surah]) -> Int {
        surahs.filter { $0.number < reference.surah }.reduce(0) { $0 + $1.ayahCount } + reference.verse
    }
}
