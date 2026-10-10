import CryptoKit
import Foundation
import QuranDataModel

/// A public-domain tafsir read from a mirror — today Tafsir al-Jalalayn — converted to a tafsir
/// pack. Ported from `Tools/CorpusBuilder/build_tafsir_db.py`, with its source, pins and checks.
///
/// The mirror (`spa5k/tafsir_api`) is acceptable here, and only here, because the work is five
/// centuries old: there is no licence to inherit from the host, only a transcription to check, and
/// the digest is what checks it.
///
/// The shape differs from a QUL tafsir in one way that matters. Every QUL ayah belongs to a group
/// whose owner carries the text; Jalalayn passes over 226 ayahs — the plain formulas that need no
/// gloss — and **those ayahs get no row at all**, not a pointer to a neighbour and not an empty
/// note. A neighbour's text under an ayah would be a gloss of one verse printed under another,
/// which is the one failure the app's "no note here" state exists to prevent (T16).
func loadMirroredTafsir(
    _ pack: BuildConfig.Packs.MirroredTafsir, config: BuildConfig, ayahIDs: [String: Int]
) async throws -> TafsirRows {
    guard pack.format == "spa5k-json" else { throw BuildError.data("\(pack.id): unsupported mirrored tafsir format '\(pack.format)'") }
    let cache = config.path(pack.cache)

    // One file per surah rather than one per ayah: the same data is published both ways, and 114
    // requests is neighbourly where 6,236 is not.
    var notes: [AyahKey: String] = [:]
    for surah in 1...114 {
        let file = cache.appendingPathComponent("\(surah).json")
        let data: Data
        if FileManager.default.fileExists(atPath: file.path) {
            data = try Data(contentsOf: file)
        } else {
            guard let url = URL(string: "\(pack.sourceURL)/\(surah).json") else { throw BuildError.data("bad URL \(pack.sourceURL)") }
            let (body, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            try require(status == 200, "\(url): HTTP \(status)")
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            try body.write(to: file, options: .atomic)
            data = body
        }
        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw BuildError.data("\(pack.id) surah \(surah): not a list of notes")
        }
        for item in items {
            func number(_ key: String) -> Int? {
                (item[key] as? Int) ?? (item[key] as? String).flatMap(Int.init)
            }
            guard let s = number("surah"), let a = number("ayah"), let raw = item["text"] as? String else {
                throw BuildError.data("\(pack.id) surah \(surah): a note without surah, ayah or text")
            }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            notes[AyahKey(surah: s, ayah: a)] = text
        }
    }

    // A note on an ayah that does not exist means the edition is numbered differently from the
    // mushaf, which would put every note after it under the wrong ayah.
    let stray = notes.keys.filter { ayahIDs[$0.description] == nil }.sorted()
    try require(stray.isEmpty, "\(pack.id) has notes on \(stray.count) ayahs the Quran does not have, from \(stray.first.map(\.description) ?? "")")

    let silent = ayahIDs.count - notes.count
    try require(silent == pack.silentCount, """
        \(pack.id) passes over \(silent) ayahs; \(pack.silentCount) were expected. Upstream has \
        changed what the commentary covers: read it before re-pinning.
        """)

    let digest = SHA256.hash(data: Data(
        notes.sorted { $0.key < $1.key }.map { "\($0.key.surah)|\($0.key.ayah)|\($0.value)" }.joined(separator: "\n").utf8
    )).map { String(format: "%02x", $0) }.joined()
    try require(digest == pack.textDigest, """
        \(pack.id)'s text has changed upstream.
          expected \(pack.textDigest)
          got      \(digest)
        This is a transcription of a five-century-old work; a diff is a change in the transcription.
        """)

    var rows = TafsirRows()
    for (key, text) in notes {
        let id = ayahIDs[key.description]!
        let html = MirroredTafsirMarkup.html(text)
        // The conversion only escapes and marks line breaks, so the sanitizer must have nothing
        // to do; anything it would change means the conversion is not the one the tests invert.
        let sanitized = try TafsirHTML.sanitize(html)
        try require(sanitized.html == html, "\(pack.id) \(key): the sanitizer rewrote the converted note")
        rows.group[id] = id
        rows.html[id] = html
    }
    rows.meta = [
        ("source_url", pack.sourceURL),
        ("digest:notes", digest),
        ("silent_ayahs", String(silent)),
    ]
    return rows
}

/// The one conversion from a mirrored note's plain text to the pack's HTML subset: escape, mark
/// each line break, wrap in a paragraph. Fixed and reversible, so a test can invert it and require
/// the original text back byte for byte — the Quran's commentary is no more edited than the Quran.
enum MirroredTafsirMarkup {
    static func html(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<p>" + escaped.replacingOccurrences(of: "\n", with: "<br>") + "</p>"
    }
}
