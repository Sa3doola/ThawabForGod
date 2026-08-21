//
//  TafsirViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The commentary on demand, with a record of what was asked for.
///
/// Locked rather than an `actor`, for the reason `StubQuranRepository` is: `TafsirRepositoring`
/// is a `nonisolated` protocol, and an actor cannot witness one.
///
/// Safety invariant for `@unchecked Sendable`: `requests` is only ever touched while `lock` is
/// held, and nothing else here is mutable.
nonisolated final class StubTafsirRepository: TafsirRepositoring, @unchecked Sendable {

    enum Request: Equatable {
        case editions
        case note(VerseReference, String)
    }

    private let lock = NSLock()
    private let editionResult: Result<[TafsirEdition], QuranStubError>
    private let noteResult: Result<String?, QuranStubError>
    private var _requests: [Request] = []

    var requests: [Request] { lock.withLock { _requests } }

    init(
        editions: Result<[TafsirEdition], QuranStubError> = .success([.stub()]),
        note: Result<String?, QuranStubError> = .success("﴿قُلْ هُوَ اللَّه أحَد﴾ خَبَر")
    ) {
        editionResult = editions
        noteResult = note
    }

    func editions() async throws -> [TafsirEdition] {
        lock.withLock { _requests.append(.editions) }
        return try editionResult.get()
    }

    func note(
        for reference: VerseReference,
        in edition: TafsirEdition.ID
    ) async throws -> TafsirNote? {
        lock.withLock { _requests.append(.note(reference, edition)) }

        guard let text = try noteResult.get() else { return nil }
        guard let edition = try editionResult.get().first(where: { $0.id == edition }) else {
            return nil
        }

        return TafsirNote(reference: reference, edition: edition, text: text)
    }
}

nonisolated extension TafsirEdition {
    static func stub(
        id: String = "jalalayn",
        arabicName: String = "تفسير الجلالين",
        englishName: String = "Tafsir al-Jalalayn",
        arabicAuthor: String = "جلال الدين المحلي وجلال الدين السيوطي",
        englishAuthor: String = "Jalal al-Din al-Mahalli and Jalal al-Din al-Suyuti",
        language: AppLanguage = .arabic,
        licence: String = "Public domain — completed 1505 CE (911 AH)"
    ) -> TafsirEdition {
        TafsirEdition(
            id: id,
            arabicName: arabicName,
            englishName: englishName,
            arabicAuthor: arabicAuthor,
            englishAuthor: englishAuthor,
            language: language,
            licence: licence
        )
    }
}

@MainActor
struct TafsirViewModelTests {

    private let kursi = VerseReference(surah: 2, verse: 255)

    private func viewModel(_ repository: StubTafsirRepository) -> TafsirViewModel {
        TafsirViewModel(useCase: GetTafsirUseCase(repository: repository))
    }

    @Test func aVerseWithANoteShowsIt() async {
        let model = viewModel(StubTafsirRepository())

        await model.load(kursi)

        guard case .note(let note) = model.phase else {
            Issue.record("expected a note, got \(model.phase)")
            return
        }
        #expect(note.reference == kursi)
        #expect(note.edition.id == "jalalayn")
    }

    /// The case this whole slice turns on. A verse the commentary passes over is *silence*, not
    /// an error and not an empty note — and the sheet is told whose silence it is, so it can say
    /// so by name rather than leaving the reader looking at a blank page.
    @Test func aVerseTheCommentaryPassesOverIsSilentRatherThanUnavailable() async {
        let model = viewModel(StubTafsirRepository(note: .success(nil)))

        await model.load(kursi)

        guard case .silent(let edition) = model.phase else {
            Issue.record("expected silence, got \(model.phase)")
            return
        }
        #expect(edition.id == "jalalayn")
    }

    @Test func aFailedReadSaysSoRatherThanClaimingSilence() async {
        let model = viewModel(StubTafsirRepository(editions: .failure(QuranStubError())))

        await model.load(kursi)

        #expect(model.phase == .unavailable)
    }

    /// No editions at all is a packaging fault, not a commentary with nothing to say — there is
    /// nobody to attribute the silence to.
    @Test func anEmptyBundleIsUnavailableRatherThanSilent() async {
        let model = viewModel(StubTafsirRepository(editions: .success([])))

        await model.load(kursi)

        #expect(model.phase == .unavailable)
    }

    @Test func theNoteIsAskedForFromTheFirstEditionWhenNoneIsNamed() async {
        let repository = StubTafsirRepository()
        let model = viewModel(repository)

        await model.load(kursi)

        #expect(repository.requests.contains(.note(kursi, "jalalayn")))
    }

    /// Opening the sheet on another verse reloads it, which is what `.task(id:)` drives.
    @Test func loadingASecondVerseReplacesTheFirst() async {
        let model = viewModel(StubTafsirRepository())
        await model.load(kursi)

        let ikhlas = VerseReference(surah: 112, verse: 1)
        await model.load(ikhlas)

        guard case .note(let note) = model.phase else {
            Issue.record("expected a note, got \(model.phase)")
            return
        }
        #expect(note.reference == ikhlas)
    }
}
