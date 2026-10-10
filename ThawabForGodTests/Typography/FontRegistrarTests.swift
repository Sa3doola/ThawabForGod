//
//  FontRegistrarTests.swift
//  ThawabForGodTests
//

import CoreText
import Foundation
import Testing
@testable import ThawabForGod

/// Every face the app asks for by name really is the face it gets.
///
/// **This suite is the only guard there is.** CoreText does not fail on a name it does not know —
/// it hands back the system face at the requested size, and a page set in Helvetica Arabic looks
/// close enough to right that nobody reading the screen would report it. So each name is asked for
/// and the face that comes back is asked *its* name; a typo, a file that did not make it into the
/// bundle or a registration that failed all show up as a mismatch here.
struct FontRegistrarTests {

    /// Taken from the types that use them rather than restated, so a name edited in the app is
    /// the name tested.
    static let postScriptNames: [String] =
        PlexAppFont.Weight.allCases.map(\.postScriptName)
        + ReaderFont.allCases.map(\.postScriptName)
        + [SurahNameGlyph.postScriptName]
        + AyahMarkerStyle.allCases.map(\.postScriptName)

    @Test(arguments: postScriptNames)
    func everyBundledFaceResolvesToItself(_ name: String) {
        FontRegistrar.registerBundledFonts()

        let font = CTFontCreateWithName(name as CFString, 12, nil)

        #expect(CTFontCopyPostScriptName(font) as String == name)
    }

    /// Twenty faces: five Plex weights, two Quranic faces, the chapter titles and twelve
    /// medallions. A count that drifts means a face was added without a name to test it by.
    @Test func theListCoversEveryBundledFace() {
        #expect(Set(Self.postScriptNames).count == 20)
    }

    // MARK: The page fonts are not registered at launch (T1)

    /// The walk skips the page-font folder by name, at any depth, and finds everything else.
    @Test func theWalkSkipsThePageFontFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = [
            "Plex.ttf",
            "Fonts/Quran/Hafs.otf",
            "\(QuranPageFonts.folderName)/p1.ttf",
            "Fonts/\(QuranPageFonts.folderName)/p604.ttf",
            "Notes.txt",
        ]
        for file in files {
            let url = root.appendingPathComponent(file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }

        let found = FontRegistrar.fontURLs(under: root).map(\.lastPathComponent).sorted()

        #expect(found == ["Hafs.otf", "Plex.ttf"])
    }

    /// The V2 faces are named `QCF2001`…`QCF2604`. After the app's own registration not one of them
    /// may be available — on a machine with the full data bundled, this is the folder really being
    /// skipped; without it, it still holds.
    @Test func noPageFontIsRegisteredAtLaunch() {
        FontRegistrar.registerBundledFonts()

        let names = CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? []

        #expect(!names.isEmpty)
        #expect(!names.contains { $0.hasPrefix("QCF2") })
    }
}
