//
//  NamesDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// Something to fail with that is `Sendable`, unlike `any Error`.
nonisolated struct NamesStubError: Error, Equatable {}

/// Names on demand, and a record of which language was asked for.
///
/// Locked rather than an `actor`, which is what this was. `NamesRepositoring` is a `nonisolated`
/// protocol, so its witness has to be nonisolated too — and an actor cannot be, which left the
/// compiler trying to apply `nonisolated` to the actor declaration itself and rejecting it. The
/// same shape as `SpyNamesTipReporting` below and every other double in this suite that stands
/// behind a `nonisolated` protocol.
///
/// Safety invariant for `@unchecked Sendable`: `languages` is only ever touched while `lock` is
/// held, and nothing else here is mutable.
nonisolated final class StubNamesRepository: NamesRepositoring, @unchecked Sendable {
    private let lock = NSLock()
    private let result: Result<[DivineName], NamesStubError>
    private var languages: [AppLanguage] = []

    /// Every language asked for, in order.
    var requestedLanguages: [AppLanguage] {
        lock.withLock { languages }
    }

    init(_ result: Result<[DivineName], NamesStubError> = .success([.stub()])) {
        self.result = result
    }

    func allNames(in language: AppLanguage) throws -> [DivineName] {
        lock.withLock { languages.append(language) }
        return try result.get()
    }
}

/// Records tip donations without touching a TipKit datastore.
nonisolated final class SpyNamesTipReporting: NamesTipReporting, @unchecked Sendable {
    /// Guarded by a lock: the protocol is `Sendable` and `namesOpened()` is awaited from a
    /// `@MainActor` view model, so nothing promises which executor the calls arrive on.
    private let lock = NSLock()
    private var _openedCalls = 0
    private var _nameOpenedCalls = 0

    var openedCalls: Int { lock.withLock { _openedCalls } }
    var nameOpenedCalls: Int { lock.withLock { _nameOpenedCalls } }

    func namesOpened() async {
        lock.withLock { _openedCalls += 1 }
    }

    func nameOpened() {
        lock.withLock { _nameOpenedCalls += 1 }
    }
}

nonisolated extension DivineName {

    /// A name with everything filled in, so a test only names the field it cares about.
    static func stub(
        id: Int = 1,
        arabic: String = "الرَّحْمَنُ",
        transliteration: String? = "Ar Rahmaan",
        meaning: String? = "The Beneficent",
        explanation: String? = nil,
        reference: String? = "(1:3) (17:110)"
    ) -> DivineName {
        DivineName(
            id: id,
            arabic: arabic,
            transliteration: transliteration,
            meaning: meaning,
            explanation: explanation,
            reference: reference
        )
    }
}
