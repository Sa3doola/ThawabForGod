//
//  QuranWidgetPublisher.swift
//  ThawabForGod
//

import Foundation

/// Writes what the two Quran widgets show into the App Group: the place last read, and the next
/// days' ayah of the day with the first enabled translation, plus a one-time copy of the Hafs font.
///
/// Ported from Mushaf's `WidgetPublisher`. The widget reads nothing else, so it needs no database,
/// no corpus and no network. **Texts are `Ayah.text` byte for byte** (the widget draws the markers),
/// and the corpus is never loaded for a widget: names and text come from the reader's corpus when
/// it is there, else from the repository, cached here.
///
/// Calls run one after another through a stored chain, so a position that settles in the middle of
/// a publish waits for it rather than racing it for the single snapshot value.
@MainActor
final class QuranWidgetPublisher {
    /// Days of "Ayah of the day" written ahead; the app republishes on every foreground.
    static let daysAhead = 30

    private let repository: any QuranRepositoring
    private let translations: any TranslationRepositoring
    private let settings: QuranReaderSettings
    private let reader: QuranReaderViewModel
    private let userData: QuranUserDataStore
    private let settingsStore: any SettingsStore
    private let widgets: any WidgetRefreshing
    private let fonts: any QuranWidgetFontInstalling
    private let hafsURL: URL?
    private let appVersion: String
    private let now: () -> Date

    private var tail: Task<Void, Never>?
    private var cachedSurahs: [Surah]?
    private var cachedAyahs: [Int: [Ayah]] = [:]
    private let style = MushafStyle.madaniV2

    init(
        repository: any QuranRepositoring,
        translations: any TranslationRepositoring,
        settings: QuranReaderSettings,
        reader: QuranReaderViewModel,
        userData: QuranUserDataStore,
        settingsStore: any SettingsStore,
        widgets: any WidgetRefreshing,
        fonts: any QuranWidgetFontInstalling,
        hafsURL: URL?,
        appVersion: String,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.translations = translations
        self.settings = settings
        self.reader = reader
        self.userData = userData
        self.settingsStore = settingsStore
        self.widgets = widgets
        self.fonts = fonts
        self.hafsURL = hafsURL
        self.appVersion = appVersion
        self.now = now
    }

    // MARK: Entry points

    /// Brings the whole snapshot up to date and reloads what changed.
    func publish() async {
        await run { [self] in
            await userData.flush()
            await publishAll()
        }
    }

    /// The reader stopped on `ayah`: updates the Continue Reading entry only.
    func positionDidSettle(_ ayah: VerseReference) {
        Task { [self] in
            await run { [self] in await publishPosition(ayah) }
        }
    }

    /// Appends `operation` to the chain and waits for it.
    private func run(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let task = Task {
            await previous?.value
            await operation()
        }
        tail = task
        await task.value
    }

    // MARK: Publishing

    private func publishAll() async {
        let old = QuranWidgetSnapshot.load(from: settingsStore)
        var snapshot = old ?? QuranWidgetSnapshot()

        if let ayah = userData.readingPosition?.ayah {
            snapshot.continueReading = await continueReading(at: ayah, keeping: old?.continueReading)
        }

        let today = DailyAyahRule.dayKey(for: now())
        let list = await AyahOfTheDayList.bundled()
        let translation = await firstTranslation()
        let fresh = old?.days.first?.day == today && old?.days.count == Self.daysAhead
            && old?.listID == list?.sha256 && old?.days.first?.translation?.packID == translation?.id.rawValue
        if !fresh, let list {
            snapshot.days = await days(list: list, translation: translation)
            snapshot.listID = list.sha256
        }

        var fontInstalled = false
        if old?.fontVersion != appVersion, let hafsURL, await fonts.install(from: hafsURL) {
            snapshot.fontVersion = appVersion
            fontInstalled = true
        }

        commit(snapshot, old: old, fontInstalled: fontInstalled)
    }

    private func publishPosition(_ ayah: VerseReference) async {
        let old = QuranWidgetSnapshot.load(from: settingsStore)
        var snapshot = old ?? QuranWidgetSnapshot()
        snapshot.continueReading = await continueReading(at: ayah, keeping: old?.continueReading)
        commit(snapshot, old: old, fontInstalled: false)
    }

    /// Saves only a changed snapshot, and reloads only the kinds whose input changed.
    private func commit(_ snapshot: QuranWidgetSnapshot, old: QuranWidgetSnapshot?, fontInstalled: Bool) {
        guard snapshot != old else { return }
        snapshot.save(to: settingsStore)
        if fontInstalled || snapshot.continueReading != old?.continueReading {
            widgets.reload(kind: QuranWidgetKind.continueReading)
        }
        if fontInstalled || snapshot.days != old?.days {
            widgets.reload(kind: QuranWidgetKind.ayahOfTheDay)
        }
    }

    // MARK: Continue reading

    private func continueReading(
        at ayah: VerseReference, keeping old: QuranWidgetSnapshot.ContinueReading?
    ) async -> QuranWidgetSnapshot.ContinueReading? {
        let corpus = reader.corpus
        // Without the corpus there is no page to report. The same place keeps its old entry rather
        // than losing the page on a cold launch.
        if corpus == nil, let old, old.ayah == ayah { return old }
        guard let surah = await surah(ayah.surah, corpus: corpus) else { return old }
        let page = reader.showsMushafPages ? corpus?.pageNumber(for: ayah) : nil
        let juz = page.flatMap { corpus?.page($0)?.juz }
        return .init(
            ayah: ayah, surahNameArabic: surah.arabicName, surahNameEnglish: surah.englishName, page: page, juz: juz
        )
    }

    // MARK: Ayah of the day

    private func firstTranslation() async -> ContentPack? {
        let installed = await translations.installed()
        return ContentPackSelection.enabledPacks(installed: installed, enabled: settings.enabledTranslations).first
    }

    private func days(list: AyahOfTheDayList, translation: ContentPack?) async -> [QuranWidgetSnapshot.DailyAyah] {
        let calendar = DailyAyahRule.calendar
        let start = now()
        var days: [QuranWidgetSnapshot.DailyAyah] = []
        for offset in 0..<Self.daysAhead {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start),
                  let entry = list.entry(for: date, calendar: calendar),
                  let daily = await dailyAyah(entry, day: DailyAyahRule.dayKey(for: date, calendar: calendar), translation: translation)
            else { continue }
            days.append(daily)
        }
        return days
    }

    /// One entry as the widget shows it: `Ayah.text` of each ayah, unmodified, and the plain
    /// translation of each. `nil` if any ayah does not resolve.
    private func dailyAyah(
        _ entry: AyahOfTheDayList.Entry, day: String, translation: ContentPack?
    ) async -> QuranWidgetSnapshot.DailyAyah? {
        let corpus = reader.corpus
        guard let surah = await surah(entry.surah, corpus: corpus) else { return nil }
        let available = await ayahs(inSurah: entry.surah, corpus: corpus)
        let texts = entry.verses.compactMap { reference in available.first { $0.id == reference }?.text }
        guard texts.count == entry.verses.count else { return nil }

        return .init(
            day: day, first: entry.first, lastVerse: entry.last,
            surahNameArabic: surah.arabicName, surahNameEnglish: surah.englishName, texts: texts,
            translation: await translationTexts(for: entry, pack: translation)
        )
    }

    /// The translation of every ayah of the entry, or `nil` if there is no pack or any ayah is missing.
    private func translationTexts(for entry: AyahOfTheDayList.Entry, pack: ContentPack?) async -> QuranWidgetSnapshot.Translation? {
        guard let pack else { return nil }
        var texts: [String] = []
        for reference in entry.verses {
            guard let found = try? await translations.text(for: reference, packs: [pack.id]).first else { return nil }
            texts.append(TranslationDocument(found).plainText)
        }
        return .init(
            packID: pack.id.rawValue, nameArabic: pack.names.ar, nameEnglish: pack.names.en,
            texts: texts, isRightToLeft: pack.direction.isRightToLeft
        )
    }

    // MARK: Corpus-free lookups

    private func surah(_ number: Int, corpus: QuranCorpus?) async -> Surah? {
        if let corpus { return corpus.surah(number) }
        if cachedSurahs == nil { cachedSurahs = try? await repository.surahs(style: style.id) }
        return cachedSurahs?.first { $0.number == number }
    }

    private func ayahs(inSurah number: Int, corpus: QuranCorpus?) async -> [Ayah] {
        if let corpus { return Array(corpus.ayahs(inSurah: number)) }
        if let cached = cachedAyahs[number] { return cached }
        let loaded = (try? await repository.ayahs(surah: number, style: style.id)) ?? []
        cachedAyahs[number] = loaded
        return loaded
    }
}
