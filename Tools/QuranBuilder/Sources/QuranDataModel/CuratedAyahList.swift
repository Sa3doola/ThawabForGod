import Foundation

/// Phase 8.0: the "Ayah of the day" list, kept by hand in `QuranData/curated/ayah-of-the-day.txt`
/// (one "s:a" or "s:a-b" per line, a "#" note after each) and shipped as
/// `Mushaf/Resources/ayah-of-the-day.json`. The pipeline checks every entry against the ayahs it
/// built; it never picks or changes an entry itself.
public enum CuratedAyahList {
    public struct Entry: Codable, Equatable, Sendable {
        public let surah: Int
        public let from: Int
        public let to: Int

        public init(surah: Int, from: Int, to: Int) {
            self.surah = surah
            self.from = from
            self.to = to
        }

        public var reference: String { from == to ? "\(surah):\(from)" : "\(surah):\(from)-\(to)" }
    }

    /// What the app reads: the entries in file order, the review status copied from the
    /// source's `# STATUS:` line, and the source's hash (the app refreshes the widget's days when
    /// it changes).
    public struct Output: Codable, Equatable, Sendable {
        public let source: String
        public let sha256: String
        public let status: String
        public let entries: [Entry]

        public init(source: String, sha256: String, status: String, entries: [Entry]) {
            self.source = source
            self.sha256 = sha256
            self.status = status
            self.entries = entries
        }
    }

    public struct ParseError: Error, CustomStringConvertible {
        public let line: Int
        public let message: String
        public var description: String { "ayah-of-the-day.txt line \(line): \(message)" }
    }

    /// The entries of the source text, in order. Fails on a malformed line or a missing note.
    public static func parse(_ text: String) throws -> [Entry] {
        var entries: [Entry] = []
        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "#", maxSplits: 1)
            let reference = parts[0].trimmingCharacters(in: .whitespaces)
            guard parts.count == 2, !parts[1].trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ParseError(line: index + 1, message: "\"\(reference)\" needs a note after \"#\"")
            }
            guard let match = reference.wholeMatch(of: /(\d+):(\d+)(?:-(\d+))?/),
                  let surah = Int(match.output.1), let from = Int(match.output.2)
            else { throw ParseError(line: index + 1, message: "\"\(reference)\" is not s:a or s:a-b") }
            entries.append(Entry(surah: surah, from: from, to: match.output.3.flatMap { Int($0) } ?? from))
        }
        return entries
    }

    /// The `# STATUS:` line's text, or "unreviewed".
    public static func status(_ text: String) -> String {
        for line in text.components(separatedBy: .newlines) {
            if let range = line.range(of: "# STATUS:") {
                return line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            }
        }
        return "unreviewed"
    }

    /// Every problem with `entries`, given each surah's ayah count (index 0 = surah 1): unknown
    /// ayahs, backwards ranges, an ayah in two entries, and fewer entries than `minimumCount`.
    public static func problems(_ entries: [Entry], ayahCounts: [Int], minimumCount: Int) -> [String] {
        var problems: [String] = []
        var owner: [String: String] = [:]
        for entry in entries {
            guard ayahCounts.indices.contains(entry.surah - 1) else {
                problems.append("\(entry.reference): no surah \(entry.surah)")
                continue
            }
            let count = ayahCounts[entry.surah - 1]
            guard entry.from >= 1, entry.from <= entry.to else {
                problems.append("\(entry.reference): not a forward range")
                continue
            }
            guard entry.to <= count else {
                problems.append("\(entry.reference): surah \(entry.surah) has \(count) ayahs")
                continue
            }
            for ayah in entry.from...entry.to {
                let key = "\(entry.surah):\(ayah)"
                if let other = owner[key] {
                    problems.append("\(entry.reference): \(key) is already in \(other)")
                } else {
                    owner[key] = entry.reference
                }
            }
        }
        if entries.count < minimumCount {
            problems.append("\(entries.count) entries; at least \(minimumCount) needed so no entry comes back within \(minimumCount) days")
        }
        return problems
    }
}
