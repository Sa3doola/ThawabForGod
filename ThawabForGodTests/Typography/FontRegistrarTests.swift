//
//  FontRegistrarTests.swift
//  ThawabForGodTests
//

import CoreText
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
}
