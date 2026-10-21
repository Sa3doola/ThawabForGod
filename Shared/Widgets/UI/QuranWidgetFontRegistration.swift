//
//  QuranWidgetFontRegistration.swift
//  ThawabForGod
//

import CoreText
import Foundation
import os

/// Registers the faces the app copied into the App Group container (Hafs, and Amiri Quran for the
/// ranges Hafs lacks). Idempotent. In `Shared/` so the test target can reach it.
nonisolated enum QuranWidgetFontRegistration {

    private static let registered = OSAllocatedUnfairLock(initialState: false)

    /// `register`, once per process once it has worked. A view asks on every render and a timeline
    /// holds eight entries, so without this the folder was listed and every file re-registered each
    /// time. A failure is not remembered: the app may copy the faces in later.
    static func registerOnce() -> Bool {
        if registered.withLock({ $0 }) { return true }
        let ok = register()
        if ok { registered.withLock { $0 = true } }
        return ok
    }

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
