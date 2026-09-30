//
//  FontRegistrar.swift
//  ThawabForGod
//

import CoreText
import Foundation

/// Makes every font file in the app bundle available to `Font.custom(_:…)`.
///
/// **Registered in code rather than through `UIAppFonts`/`ATSApplicationFontsPath`**, because
/// that pair is two Info.plist keys with two different shapes on two platforms, and a list of file
/// names that has to be kept in step with a folder by hand. `CTFontManagerRegisterFontsForURL` is
/// the same call on iOS and macOS, and walking the bundle means a face added to `Resources/Fonts`
/// is registered by being there.
///
/// It lives in the app's `Core`, not in `Shared`, because the files are only in the app's bundle:
/// the widget and the notification extension draw in the system face, and neither carries two
/// megabytes of Quranic fonts inside a memory budget measured in tens.
///
/// A failure is logged in debug builds and otherwise ignored. A face that did not register falls
/// back to the system face — wrong, but readable — and a crash at launch over typography would be
/// a much worse trade. `FontRegistrarTests` is what catches a face that silently went missing.
nonisolated enum FontRegistrar {

    /// Registers the bundle's fonts, once per process however often it is called.
    ///
    /// Called from `ThawabForGodApp.init()`, before any view exists to ask for a face. Safe to
    /// call again from a test or a preview: the work is behind a `static let`, which Swift runs
    /// exactly once and thread-safely.
    static func registerBundledFonts() {
        _ = registration
    }

    private static let registration: Void = {
        for url in fontURLs(in: Bundle.main) {
            register(url)
        }
    }()

    /// Every `.ttf` and `.otf` under the bundle's resources, at any depth.
    ///
    /// Recursive on purpose. Whether a synchronized folder's structure survives into the built
    /// bundle is Xcode's decision rather than this project's, and a search that assumed either
    /// answer would find nothing the day the other one was true.
    private static func fontURLs(in bundle: Bundle) -> [URL] {
        guard
            let root = bundle.resourceURL,
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
    }

    private static func register(_ url: URL) {
        var error: Unmanaged<CFError>?
        guard !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else { return }

        #if DEBUG
        let failure = error?.takeRetainedValue()
        // Already registered is success by another name — a test host has run the app's own
        // launch before the test asks again.
        if let failure,
           CFErrorGetCode(failure) == CTFontManagerError.alreadyRegistered.rawValue {
            return
        }
        print("FontRegistrar: could not register \(url.lastPathComponent): \(String(describing: failure))")
        #else
        error?.release()
        #endif
    }
}
