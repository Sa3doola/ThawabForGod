//
//  SurahInfoViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// A surah's facts, read from the corpus.
nonisolated struct SurahInfoFacts: Equatable, Sendable {
    let surah: Surah
    /// The pages the surah is on; `nil` in a build without the printed pages.
    let pages: ClosedRange<Int>?
    /// The juz its first ayah is in.
    let startJuz: Int

    /// `nil` for a surah the corpus does not have.
    init?(surah number: Int, corpus: QuranCorpus) {
        guard let surah = corpus.surah(number) else { return nil }
        self.surah = surah
        // The page where the last ayah *starts*: its end marker can spill onto the next page, and
        // that page is not one the surah is on.
        // The one place surah info asks whether the build has printed pages: no range without them.
        if corpus.hasPages, let first = surah.startPage {
            let last = corpus.pageNumber(for: VerseReference(surah: number, verse: surah.ayahCount)) ?? first
            pages = first...max(first, last)
        } else {
            pages = nil
        }
        startJuz = corpus.ayah(VerseReference(surah: number, verse: 1))?.juz ?? 1
    }
}

/// One surah's introduction, parsed and ready to draw.
nonisolated struct SurahInfoContent: Equatable, Sendable {
    let surah: Int
    let pack: ContentPack
    let document: TafsirDocument
}

/// Whether surah info exists in this interface language, and the introduction being read.
///
/// One per section, owned by `AppContainer`, so that the Library can ask `isAvailable` before it
/// offers the screen and the screen can read the same answer.
@Observable
@MainActor
final class SurahInfoViewModel {
    nonisolated enum Phase: Equatable, Sendable {
        case loading
        case loaded(SurahInfoContent)
        /// The pack has nothing for this surah, or there is no pack.
        case missing
    }

    /// The surah-info pack in the interface language, once `prepare` has asked. `nil`: none.
    private(set) var pack: ContentPack?
    private(set) var phase: Phase = .loading

    @ObservationIgnored private let repository: any SurahInfoRepositoring
    @ObservationIgnored private let reader: QuranReaderViewModel
    /// The language `prepare` has already answered for, so asking twice costs nothing.
    @ObservationIgnored private var preparedLanguage: AppLanguage?
    /// The surah `phase` is about, `nil` before anything was asked for. A result for any other
    /// surah is stale: the view model is reused across screens, and an answer that arrives after
    /// the reader has gone on to another surah must not overwrite it.
    private(set) var subject: Int?

    init(repository: any SurahInfoRepositoring, reader: QuranReaderViewModel) {
        self.repository = repository
        self.reader = reader
    }

    /// Whether any row may offer surah info. False until `prepare` has answered.
    var isAvailable: Bool { pack != nil }

    /// Asks once which pack serves this interface language.
    func prepare(language: AppLanguage) async {
        guard preparedLanguage != language else { return }
        let found = await repository.pack(for: language)
        pack = found
        preparedLanguage = language
    }

    /// The phase to draw for `surah`: `phase` when it is about that surah, `.loading` otherwise.
    ///
    /// The view model is shared and a screen's `.task` runs after its first render, so the phase
    /// on hand at that first frame belongs to the previous surah. Drawing it would print another
    /// surah's text, or a "missing" that was established for another surah.
    func phase(for surah: Int) -> Phase {
        subject == surah ? phase : .loading
    }

    func load(surah: Int) async {
        // A rebuilt view tree asks again for the screen it already has.
        if subject == surah, case .loaded = phase { return }
        subject = surah
        phase = .loading

        guard let pack else {
            phase = .missing
            return
        }
        let info: SurahInfo?
        do {
            info = try await repository.info(surah: surah, pack: pack.id)
        } catch is CancellationError {
            // Backing out is not an answer: write nothing, so the next load starts again.
            return
        } catch {
            // A broken pack reads as missing until packs have a failure state of their own (M5.3).
            info = nil
        }
        guard !Task.isCancelled, subject == surah else { return }
        guard let info else {
            phase = .missing
            return
        }
        let document = await TafsirDocument.parsed(html: info.html)
        guard !Task.isCancelled, subject == surah else { return }
        phase = .loaded(SurahInfoContent(surah: surah, pack: pack, document: document))
    }

    func facts(for surah: Int) -> SurahInfoFacts? {
        reader.corpus.flatMap { SurahInfoFacts(surah: surah, corpus: $0) }
    }
}
