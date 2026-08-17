//
//  TasbihDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// Something to fail with that is `Sendable`, unlike `any Error`.
nonisolated struct TasbihStubError: Error, Equatable {}

/// Presets on demand, and a record of which language was asked for.
actor StubTasbihCatalog: TasbihCatalogProviding {
    private let result: Result<[TasbihDhikr], TasbihStubError>
    private(set) var requestedLanguages: [AppLanguage] = []

    init(_ result: Result<[TasbihDhikr], TasbihStubError> = .success([.stub()])) {
        self.result = result
    }

    func presets(in language: AppLanguage) throws -> [TasbihDhikr] {
        requestedLanguages.append(language)
        return try result.get()
    }
}

/// An in-memory stand-in for the SwiftData store that remembers every write.
///
/// The saves are what most of the view model's tests are actually about — *when* a count reaches
/// storage is the whole point of the throttling — so they are recorded in order rather than
/// collapsed to a count.
actor StubTasbihProgress: TasbihProgressRepositoring {
    private var stored: [TasbihDhikr.ID: TasbihSession] = [:]

    private(set) var savedSessions: [TasbihSession] = []
    private(set) var resetIdentifiers: [TasbihDhikr.ID] = []

    /// Set to fail every write, for the path where the store is unwritable.
    var failsToSave = false

    init(seeded: [TasbihSession] = []) {
        for session in seeded {
            stored[session.dhikrID] = session
        }
    }

    func setFailsToSave(_ fails: Bool) {
        failsToSave = fails
    }

    func session(for dhikrID: TasbihDhikr.ID) throws -> TasbihSession? {
        stored[dhikrID]
    }

    func save(_ session: TasbihSession) throws {
        if failsToSave { throw TasbihStubError() }
        stored[session.dhikrID] = session
        savedSessions.append(session)
    }

    func reset(dhikrID: TasbihDhikr.ID) throws {
        stored[dhikrID] = nil
        resetIdentifiers.append(dhikrID)
    }
}

/// Records tip donations without touching a TipKit datastore.
nonisolated final class SpyTasbihTipReporting: TasbihTipReporting, @unchecked Sendable {
    /// Guarded by a lock: `counted()` is called from the main actor in these tests, but the
    /// protocol is `Sendable` and nothing promises that stays true.
    private let lock = NSLock()
    private var _countedCalls = 0
    private var _resetCalls = 0

    var countedCalls: Int { lock.withLock { _countedCalls } }
    var resetCalls: Int { lock.withLock { _resetCalls } }

    func counted() {
        lock.withLock { _countedCalls += 1 }
    }

    func resetPerformed() {
        lock.withLock { _resetCalls += 1 }
    }
}

nonisolated extension TasbihDhikr {

    /// A preset with everything filled in, so a test only names the field it cares about.
    static func stub(
        id: String = "subhanallah",
        arabicText: String = "سُبْحَانَ اللَّهِ",
        translation: String? = "Glory be to Allah",
        targetCount: Int = 33
    ) -> TasbihDhikr {
        TasbihDhikr(
            id: id,
            arabicText: arabicText,
            translation: translation,
            targetCount: targetCount
        )
    }
}
