// What the app bundles is what the builder wrote. The builder installs its outputs into the app
// target's resources (T4), so a rebuild that was not copied in, or a hand-edited copy, shows up here
// rather than on a device. The tanzil files are committed; the qul ones are git-ignored by name and
// exist only where the qul profile has been built.

import Foundation
import QuranDataModel
import Testing

private func sameFile(_ installed: URL, _ built: URL) throws -> Bool {
    try SourceManifest.sha256(of: installed) == SourceManifest.sha256(of: built)
}

private func files(in folder: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }.sorted()
}

@Suite(.enabled(if: Paths.tanzilBuilt, "build the tanzil profile first"))
struct TanzilInstalled {
    @Test func theBundledDatabaseIsThisBuild() throws {
        #expect(try sameFile(Paths.installedQuranSQLite, Paths.tanzilSQLite))
    }

    @Test func theBundledPacksAreThisBuild() throws {
        let built = try files(in: Paths.packs("tanzil"))
        #expect(built == ["tafsir-ar-jalalayn.sqlite"])
        for file in built {
            #expect(try sameFile(Paths.installedPacks.appendingPathComponent(file), Paths.packs("tanzil").appendingPathComponent(file)), "\(file)")
        }
    }
}

@Suite(.enabled(if: Paths.qulBuilt, "build the qul profile first"))
struct QULInstalled {
    @Test func theBundledDatabaseIsThisBuild() throws {
        #expect(try sameFile(Paths.installedMushafSQLite, Paths.quranSQLite))
    }

    @Test func theBundledPacksAreThisBuild() throws {
        for file in try files(in: Paths.packs("qul")) {
            #expect(try sameFile(Paths.installedPacks.appendingPathComponent(file), Paths.packs("qul").appendingPathComponent(file)), "\(file)")
        }
    }

    @Test func theBundledFontsAreThisBuild() throws {
        let built = try files(in: Paths.bundledFonts)
        #expect(built == ["quran-common.ttf", "surah-header.ttf", "surah-name-v2.ttf"])
        for file in built {
            #expect(try sameFile(Paths.installedQuranFonts.appendingPathComponent(file), Paths.bundledFonts.appendingPathComponent(file)), "\(file)")
        }
    }
}
