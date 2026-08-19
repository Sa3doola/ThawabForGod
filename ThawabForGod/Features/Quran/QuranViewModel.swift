//
//  QuranViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives both Quran screens: the list of chapters and parts, and the text of the one being read.
///
/// One type for two screens, the same shape as `AdhkarViewModel` — which is what lets the
/// reading screen be handed a view model rather than build one out of a use case it would have
/// to be given anyway. It owns no text of its own: every verse comes from the corpus through
/// `GetQuranUseCase`, which is what lets this be tested against a handful of stub values instead
/// of a database.
@Observable
@MainActor
final class QuranViewModel {

    /// Which list the segmented control is showing.
    enum Section: Hashable, CaseIterable {
        case surahs
        case juz
    }

    /// What the list screen has to show.
    enum ListPhase: Equatable {
        case loading
        case ready(surahs: [Surah], juz: [Juz])
        /// The corpus could not be read — a packaging fault, not something the reader did.
        case unavailable
    }

    /// What the reading screen has to show.
    enum ReadingPhase: Equatable {
        case loading
        case ready(Reading)
        case unavailable
    }

    /// A loaded span of text, and what is needed to draw its headings.
    struct Reading: Equatable {

        /// The verses, in reading order.
        let verses: [Verse]

        /// The chapters those verses fall in, by number. Held because a part crosses chapter
        /// boundaries and the reader has to be told when it does; looking that up per verse
        /// against the repository would be a query inside a scroll.
        let surahs: [Int: Surah]

        /// The chapters in the order they appear — for a single chapter, one.
        var surahOrder: [Int] {
            var seen: Set<Int> = []
            return verses.map(\.surahNumber).filter { seen.insert($0).inserted }
        }

        /// The verses of one chapter *within this span*, which for a part is not every verse
        /// that chapter has.
        func verses(inSurah number: Int) -> [Verse] {
            verses.filter { $0.surahNumber == number }
        }

        /// Whether the chapter's basmala heading belongs above it here.
        ///
        /// Only where this span actually contains that chapter's first verse. Juz 2 opens at
        /// 2:142, and printing the heading that belongs above 2:1 would tell the reader they are
        /// at the start of Al-Baqara when they are arriving in the middle of it.
        func showsBismillah(forSurah number: Int) -> Bool {
            guard surahs[number]?.bismillah != nil else { return false }
            return verses(inSurah: number).first?.number == 1
        }
    }

    // MARK: State

    private(set) var listPhase: ListPhase = .loading
    private(set) var readingPhase: ReadingPhase = .loading

    /// Settable from the view because a `Picker` needs a two-way binding; routing a segment
    /// change through a method would buy nothing.
    var section: Section = .surahs

    @ObservationIgnored private let useCase: GetQuranUseCase

    init(useCase: GetQuranUseCase) {
        self.useCase = useCase
    }

    // MARK: Derived

    var surahs: [Surah] {
        guard case .ready(let surahs, _) = listPhase else { return [] }
        return surahs
    }

    var juz: [Juz] {
        guard case .ready(_, let juz) = listPhase else { return [] }
        return juz
    }

    // MARK: Loading

    /// Loads both lists.
    ///
    /// Together rather than one per segment: they come out of the same file, they are 144 small
    /// rows between them, and loading on demand would put a spinner in front of a reader who
    /// only flicked a segmented control.
    ///
    /// Driven from the view's `.task`, so SwiftUI owns the lifetime — there is no stored `Task`
    /// here and nothing to cancel by hand.
    func loadList() async {
        listPhase = .loading

        do {
            // Concurrently, because they are two independent reads and the second has no reason
            // to wait on the first.
            async let surahs = useCase.surahs()
            async let juz = useCase.juzList()

            let loaded = try await (surahs: surahs, juz: juz)
            guard !Task.isCancelled else { return }
            listPhase = .ready(surahs: loaded.surahs, juz: loaded.juz)
        } catch {
            guard !Task.isCancelled else { return }
            listPhase = .unavailable
        }
    }

    /// Loads the verses of a chapter or a part, with the chapters needed to head them.
    func load(_ reading: QuranReading) async {
        readingPhase = .loading

        do {
            async let chapters = useCase.surahs()
            async let verses = fetchVerses(for: reading)

            let loaded = try await (chapters: chapters, verses: verses)
            guard !Task.isCancelled else { return }

            // Nothing coming back is a failure rather than an empty screen: every chapter and
            // every part of the mushaf has verses, so an empty result means the corpus is not
            // what it claims to be.
            guard !loaded.verses.isEmpty else {
                readingPhase = .unavailable
                return
            }

            readingPhase = .ready(
                Reading(
                    verses: loaded.verses,
                    surahs: Dictionary(uniqueKeysWithValues: loaded.chapters.map { ($0.id, $0) })
                )
            )
        } catch {
            guard !Task.isCancelled else { return }
            readingPhase = .unavailable
        }
    }

    private func fetchVerses(for reading: QuranReading) async throws -> [Verse] {
        switch reading {
        case .surah(let number):
            try await useCase.verses(inSurah: number)
        case .juz(let number):
            try await useCase.verses(inJuz: number)
        }
    }
}
