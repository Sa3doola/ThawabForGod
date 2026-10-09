// swift-tools-version: 6.0
// Builds the Quran database the app reads, from one of two input profiles
// (QURAN_MIGRATION_PLAN.md, T4):
//
//   tanzil  Tanzil's Uthmani text and metadata, downloaded and pinned. Public, committable.
//   qul     The Quranic Universal Library downloads in QuranData/raw (git-ignored): the KFGQPC V2
//           page layout, glyph codes and fonts. Built locally, never committed.
//
// Both write the same schema. Not part of the app target; ported from Mushaf's BuildQuranData.

import PackageDescription

let package = Package(
    name: "QuranBuilder",
    platforms: [.macOS(.v15)],
    dependencies: [
        // The one Arabic fold, shared with the app's search, so the index and the queries agree.
        .package(path: "../../Packages/ArabicText"),
    ],
    targets: [
        // Static tables, SOURCES.md hashes, the size report and a small sqlite3 wrapper.
        .target(name: "QuranDataModel", linkerSettings: [.linkedLibrary("sqlite3")]),
        // Writes quran.sqlite with the system sqlite3 (FTS5 included); GRDB is not needed for a
        // one-shot writer.
        .executableTarget(
            name: "QuranBuilder",
            dependencies: ["QuranDataModel", .product(name: "ArabicText", package: "ArabicText")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "QuranDataIntegrityTests",
            dependencies: ["QuranDataModel", .product(name: "ArabicText", package: "ArabicText")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
    ]
)
