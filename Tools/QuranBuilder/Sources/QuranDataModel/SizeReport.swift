import Foundation

/// Raw and compressed size of everything the pipeline puts in the app bundle, checked against
/// the budget (QURAN_MIGRATION_PLAN.md, T6: the app is offline-only, so all data ships in the
/// download).
///
/// "Compressed" is each file deflated on its own (zlib), close to how an .ipa (a zip) and the
/// App Store download store it. The app binary and asset catalog are not included: archive the
/// app for the real .ipa size.
public struct SizeReport: Sendable {
    public struct Item: Sendable {
        /// Path relative to the measured folder, prefixed with that folder's name; a subfolder of
        /// many files is one item.
        public let path: String
        public let files: Int
        public let rawBytes: Int
        public let compressedBytes: Int
    }

    public let items: [Item]

    public var rawBytes: Int { items.reduce(0) { $0 + $1.rawBytes } }
    public var compressedBytes: Int { items.reduce(0) { $0 + $1.compressedBytes } }

    /// Measures every file under each folder. Files directly in a folder are items of their own;
    /// anything in a subfolder (`Packs/`, `madaniV2/`) is counted as one item per subfolder.
    /// A folder that does not exist is skipped, so a build without the optional data still
    /// reports what it has.
    public init(folders: [URL]) throws {
        let manager = FileManager.default
        var groups: [String: (files: Int, raw: Int, compressed: Int)] = [:]
        for folder in folders where manager.fileExists(atPath: folder.path) {
            try Self.measure(folder, into: &groups)
        }
        items = groups.map { Item(path: $0.key, files: $0.value.files, rawBytes: $0.value.raw, compressedBytes: $0.value.compressed) }
            .sorted { $0.compressedBytes > $1.compressedBytes }
    }

    public init(resources: URL) throws {
        try self.init(folders: [resources])
    }

    private static func measure(_ folder: URL, into groups: inout [String: (files: Int, raw: Int, compressed: Int)]) throws {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let base = folder.standardizedFileURL.path
        let name = folder.lastPathComponent
        for case let url as URL in enumerator {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                  !url.lastPathComponent.hasPrefix(".") else { continue }
            let relative = String(url.standardizedFileURL.path.dropFirst(base.count + 1))
            let parts = relative.split(separator: "/")
            let key = name + "/" + (parts.count > 1 ? parts.dropLast().joined(separator: "/") + "/" : relative)
            let data = try Data(contentsOf: url)
            let compressed = try (data as NSData).compressed(using: .zlib).length
            var group = groups[key, default: (0, 0, 0)]
            group.files += 1
            group.raw += data.count
            group.compressed += compressed
            groups[key] = group
        }
    }

    /// One line per item, largest first, then the totals against the budget.
    public func lines(budgetCompressedMB: Int, budgetInstalledMB: Int) -> [String] {
        func mb(_ bytes: Int) -> String { String(format: "%7.1f MB", Double(bytes) / 1_048_576) }
        var lines = items.map { "\(mb($0.rawBytes)) raw \(mb($0.compressedBytes)) compressed  \($0.path)\($0.files > 1 ? " (\($0.files) files)" : "")" }
        lines.append("\(mb(rawBytes)) raw \(mb(compressedBytes)) compressed  total bundled data (budget: \(budgetCompressedMB) MB compressed, \(budgetInstalledMB) MB installed)")
        return lines
    }

    /// Over-budget messages; empty when the data fits.
    public func violations(budgetCompressedMB: Int, budgetInstalledMB: Int) -> [String] {
        var result: [String] = []
        if compressedBytes > budgetCompressedMB * 1_048_576 {
            result.append("bundled data is \(compressedBytes / 1_048_576) MB compressed, over the \(budgetCompressedMB) MB budget")
        }
        if rawBytes > budgetInstalledMB * 1_048_576 {
            result.append("bundled data is \(rawBytes / 1_048_576) MB installed, over the \(budgetInstalledMB) MB budget")
        }
        return result
    }
}
