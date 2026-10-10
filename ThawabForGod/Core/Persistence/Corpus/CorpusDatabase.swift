//
//  CorpusDatabase.swift
//  ThawabForGod
//

import Foundation
import GRDB
import os

/// Opens a read-only SQLite file that ships inside the app bundle.
///
/// Generic on purpose: it knows about *a* corpus file, never about adhkar. Each content feature
/// brings its own tables and its own repository; this type's whole job is to hand them one
/// shared, correctly-configured reader.
///
/// **A `DatabaseQueue`, not a `DatabasePool`.** A pool's concurrent readers depend on WAL mode,
/// and entering WAL means writing a `-wal` and a `-shm` file next to the database — impossible
/// beside a file in a signed bundle, and meaningless for data nobody writes. A queue serialises
/// reads instead, which for a corpus this size is the cheaper of the two anyway.
///
/// Opening is deferred to the first `reader()` call rather than done in `init`, so constructing
/// `AppContainer` never touches the file system and a missing resource surfaces as an error on
/// one screen instead of a throwing initialiser at launch.
nonisolated final class CorpusDatabase: CorpusDatabaseProviding {
    /// Where the file is: a bundle resource by name, or a file already located — a Quran pack,
    /// found by scanning the bundle for its prefix, or a test's fixture.
    private enum Location {
        case resource(name: String, fileExtension: String, bundle: Bundle)
        case file(URL)
    }

    private let location: Location

    /// The opened queue, kept so the file is opened once however many repositories read it.
    ///
    /// A lock rather than an actor because `reader()` is synchronous — repositories do their own
    /// hopping off the main actor around the *queries*, which is where the time actually goes.
    /// `OSAllocatedUnfairLock` over `NSLock` for its typed state: the cached value cannot be
    /// read without taking the lock, so there is no unsynchronised path to get wrong.
    ///
    /// Invariant: nothing suspends inside `withLock`. Opening a SQLite file is a synchronous
    /// syscall, so the lock is held for a bounded, non-reentrant stretch.
    private let cache = OSAllocatedUnfairLock<(any DatabaseReader)?>(initialState: nil)

    /// - Parameters:
    ///   - name: the resource's file name, without extension.
    ///   - fileExtension: its extension, as it appears in `Resources`.
    ///   - bundle: which bundle to look in. Tests pass their own to read a fixture.
    init(name: String, fileExtension: String = "sqlite", bundle: Bundle = .main) {
        location = .resource(name: name, fileExtension: fileExtension, bundle: bundle)
    }

    /// A file that has already been found. Opening is still deferred to the first read.
    init(url: URL) {
        location = .file(url)
    }

    func reader() throws -> any DatabaseReader {
        try cache.withLock { cached in
            if let cached {
                return cached
            }

            let opened = try open()
            cached = opened
            return opened
        }
    }

    private func open() throws -> any DatabaseReader {
        let url: URL
        switch location {
        case .resource(let name, let fileExtension, let bundle):
            guard let found = bundle.url(forResource: name, withExtension: fileExtension) else {
                throw CorpusDatabaseError.resourceMissing(name: "\(name).\(fileExtension)")
            }
            url = found
        case .file(let file):
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw CorpusDatabaseError.resourceMissing(name: file.lastPathComponent)
            }
            url = file
        }

        var configuration = Configuration()
        // Belt and braces. The file in the bundle is unwritable anyway, but saying so here means
        // an accidental `INSERT` fails as a clear SQLite error rather than as a confusing
        // permissions problem — and it lets SQLite skip its journalling machinery entirely.
        configuration.readonly = true

        return try DatabaseQueue(path: url.path, configuration: configuration)
    }
}
