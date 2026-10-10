//
//  QuranStoredTextTests.swift
//  ThawabForGodTests
//

import CryptoKit
import Foundation
import GRDB
import Testing
@testable import ThawabForGod

/// The stored Quran text is the text the app had before the migration, verse for verse and byte for
/// byte (M5.0 (a)).
///
/// The builder's `TanzilProfile.textIsByteIdenticalToThePreMigrationCorpus` holds the built database
/// to the same digest, but it is skipped wherever the profile has not been built. This is the same
/// check over the database the app ships, so it cannot be skipped in any clone.
struct QuranStoredTextTests {

    /// The builder's `Fingerprint.of`, reproduced: one line per ayah in id order, `s:v<TAB>text_hafs`,
    /// the lines joined by newlines, SHA-256 in lower-case hex.
    private static func fingerprint(_ lines: [String]) -> String {
        SHA256.hash(data: Data(lines.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Copied character for character from `PreMigrationCorpus.text` in
    /// `Tools/QuranBuilder/Tests/QuranDataIntegrityTests/Expectations.swift` (line 102). The two must
    /// agree. If they do not, that is a finding about the stored text or the fingerprint; this value is
    /// never edited to make the test pass.
    private static let preMigrationText = "ab0242de736a16e11d44df50b5737863b89956af5a41b556586d1bdd07f624cd"

    @Test func storedTextIsByteIdenticalToThePreMigrationCorpus() async throws {
        let lines = try await QuranTestData.publicDatabase.corpus.reader().read { db in
            try Row.fetchAll(db, sql: "SELECT surah, ayah, text_hafs FROM ayah ORDER BY id").map { row -> String in
                let surah: Int = row[0]
                let verse: Int = row[1]
                let text: String = row[2]
                return "\(surah):\(verse)\t\(text)"
            }
        }
        #expect(lines.count == 6236)
        #expect(Self.fingerprint(lines) == Self.preMigrationText)
    }

    /// The same digest, built from what the repository hands out rather than from the column. It pins
    /// the link the test above assumes and does not check: that `Ayah.text` is `text_hafs`, unchanged.
    /// A trim, normalisation or lift added to `QuranRepository` later would pass the test above and fail
    /// this one. The lines are in the corpus's own order, not an assumed one; the digest is order-
    /// sensitive, so it also pins that the corpus comes out in database id order.
    @Test func repositoryHandsOutTheStoredTextUnchanged() async throws {
        let corpus = try await QuranTestData.repository(QuranTestData.publicDatabase).loadCorpus(style: .madaniV2)
        let lines = corpus.ayahs.map { "\($0.id.surah):\($0.id.verse)\t\($0.text)" }
        #expect(lines.count == 6236)
        #expect(Self.fingerprint(lines) == Self.preMigrationText)
    }
}
