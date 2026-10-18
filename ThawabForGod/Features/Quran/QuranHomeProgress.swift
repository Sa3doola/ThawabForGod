//
//  QuranHomeProgress.swift
//  ThawabForGod
//

/// What Home knows about the Quran: where the reader stopped and the name of the surah. Home gets
/// this protocol and never the store, the reader or the corpus.
@MainActor
final class QuranHomeProgress: HomeQuranProgressProviding {
    private let userData: QuranUserDataStore
    private let reader: QuranReaderViewModel
    private let repository: any QuranRepositoring
    /// Read once, only when the reader's corpus has not loaded. Home never loads the whole corpus.
    private var cachedSurahs: [Surah]?

    init(userData: QuranUserDataStore, reader: QuranReaderViewModel, repository: any QuranRepositoring) {
        self.userData = userData
        self.reader = reader
        self.repository = repository
    }

    /// Waits for a reader that was just left to finish writing, so Home reads the settled place
    /// rather than racing it.
    func settle() async {
        await reader.awaitSessionEnd()
        await userData.flush()
    }

    func lastReadAyah() async -> VerseReference? {
        guard let ayah = userData.readingPosition?.ayah, let surah = await surah(ayah.surah),
              (1...surah.ayahCount).contains(ayah.verse) else { return nil }
        return ayah
    }

    func surahName(_ surah: Int, in language: AppLanguage) async -> String? {
        await self.surah(surah)?.name(in: language)
    }

    private func surah(_ number: Int) async -> Surah? {
        if let surah = reader.corpus?.surah(number) { return surah }
        if cachedSurahs == nil {
            cachedSurahs = try? await repository.surahs(style: MushafStyle.madaniV2.id)
        }
        return cachedSurahs?.first { $0.number == number }
    }
}
