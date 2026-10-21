//
//  QuranPlatformTests.swift
//  ThawabForGodUITests
//
//  M8-C2 (docs/quran-migration/design/M8-C2.md): the platform pass over the Quran tab, run on the
//  iPhone, the Duo, the iPad and the Mac, in full and public data. This file holds the class and its
//  setUp only; the tests are `extension QuranPlatformTests` in the `QuranPlatformTests+*.swift`
//  files, and the helpers they share (`launchPlatform`, `toggleDisplayMode`, `openReaderSettings`,
//  `selectSection`, `TestRun`, ...) are in `QuranUITestSupport.swift`.
//
//  A run is shaped by the runner's environment, not by the tests: `TEST_RUNNER_QURAN_DATA=public`,
//  `TEST_RUNNER_QURAN_LANGUAGE=ar`, `TEST_RUNNER_QURAN_APPEARANCE=dark`.
//

import XCTest

@MainActor
final class QuranPlatformTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }
}
