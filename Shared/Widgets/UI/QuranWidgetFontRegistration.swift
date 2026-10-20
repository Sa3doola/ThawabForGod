//
//  QuranWidgetFontRegistration.swift
//  ThawabForGod
//

import CoreText
import Foundation

/// Registers the faces the app copied into the App Group container (Hafs, and Amiri Quran for the
/// ranges Hafs lacks). Idempotent. In `Shared/` so the test target can reach it.
nonisolated enum QuranWidgetFontRegistration {

    /// Registers every font file in `folder` for this process; true when the Hafs face resolves.
    static func register(folder: URL? = QuranWidgetFont.containerFolderURL) -> Bool {
        if let folder,
           let files = try? FileManager.default.contentsOfDirectory(
               at: folder, includingPropertiesForKeys: nil) {
            for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
                // An already-registered file reports an error; the name check below is the truth.
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        return isKnown(QuranWidgetFont.postScriptName)
    }

    private static func isKnown(_ postScriptName: String) -> Bool {
        let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        return CTFontCopyPostScriptName(font) as String == postScriptName
    }
}
