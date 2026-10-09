import CryptoKit
import Foundation

/// The SHA-256 of every raw input, as recorded in `QuranData/SOURCES.md`.
///
/// A table row qualifies when it has a backticked path (relative to `QuranData/raw/`)
/// followed by a 64-digit hex hash, e.g. `| … | \`layout/qpc-v2-15-lines.db\` | e4df…dd8c | … |`.
public struct SourceManifest: Sendable {
    public let sha256ByPath: [String: String]

    public init(markdown: String) {
        var hashes: [String: String] = [:]
        let pattern = /`([^`]+)`\s*\|\s*([0-9a-f]{64})\s*\|/
        for line in markdown.split(separator: "\n") where line.hasPrefix("|") {
            if let match = line.firstMatch(of: pattern) {
                hashes[String(match.1)] = String(match.2)
            }
        }
        sha256ByPath = hashes
    }

    public init(contentsOf url: URL) throws {
        self.init(markdown: try String(contentsOf: url, encoding: .utf8))
    }

    public enum VerificationError: Error, Equatable, CustomStringConvertible {
        case notListed(String)
        case missing(String)
        case mismatch(path: String, expected: String, actual: String)

        public var description: String {
            switch self {
            case .notListed(let path): "\(path) is not listed in SOURCES.md"
            case .missing(let path): "\(path) is missing from QuranData/raw"
            case .mismatch(let path, let expected, let actual): "\(path): SOURCES.md has \(expected), the file is \(actual)"
            }
        }
    }

    /// Hash of the file at `url`, checked against the entry for `path`.
    public func verify(path: String, url: URL) throws -> String {
        guard let expected = sha256ByPath[path] else { throw VerificationError.notListed(path) }
        guard FileManager.default.fileExists(atPath: url.path) else { throw VerificationError.missing(path) }
        let actual = try Self.sha256(of: url)
        guard actual == expected else { throw VerificationError.mismatch(path: path, expected: expected, actual: actual) }
        return actual
    }

    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
