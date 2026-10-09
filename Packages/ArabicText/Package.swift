// swift-tools-version: 6.0
// The Arabic text rules the app and the Quran data pipeline share, so a search index and the
// queries run against it fold text identically (QURAN_MIGRATION_PLAN.md, T3).
//
// A package rather than a folder in the app because `Tools/QuranBuilder` is a command-line Swift
// package and has to fold the corpus with *this* code — two copies of a folding rule are two
// things to keep in step, and the failure when they drift is silence rather than an error.
//
// Swift 6 language mode, unlike the app (still 5.0): nothing here holds state, so the stricter
// checking costs nothing and keeps the package honest for the day the app flips.

import PackageDescription

let package = Package(
    name: "ArabicText",
    platforms: [.iOS(.v17), .macOS(.v15)],
    products: [
        .library(name: "ArabicText", targets: ["ArabicText"]),
    ],
    targets: [
        .target(name: "ArabicText"),
        .testTarget(
            name: "ArabicTextTests",
            dependencies: ["ArabicText"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
