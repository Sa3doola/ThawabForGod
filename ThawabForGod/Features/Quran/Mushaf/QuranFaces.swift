//
//  QuranFaces.swift
//  ThawabForGod
//

import CoreText
import SwiftUI

/// Which of the Mushaf's bundled faces (`QuranFace`) actually registered, and how to set them.
///
/// Mushaf's `QuranFonts`. A public clone bundles KFGQPC Hafs alone — the three QUL faces are built
/// locally and git-ignored (D1) — so every view that draws a QUL face asks `contains(_:)` first and
/// has a fallback that draws something true: a surah's name in the app's face rather than a
/// ligature string such as "surah002" printed in Latin letters.
///
/// **Sizes here are fixed, and that is the renderer's documented exception to `AppTextStyle`.** A
/// Mushaf page is fitted to the screen: its font size comes out of `MushafPageMetrics`, measured
/// so the widest line fills the width, and scaling that for Dynamic Type would push lines off the
/// page. The chrome around the page (header and footer) stays on `appFont(_:weight:)`; only what is
/// drawn *inside* the fitted page — the text, the headers, the margin labels — sizes itself here.
nonisolated struct QuranFaces: Equatable, Sendable {
    let available: Set<QuranFace>

    /// Nothing registered: previews and tests that never ran `FontRegistrar`.
    static let unavailable = QuranFaces(available: [])

    /// The faces that resolve to themselves right now. CoreText substitutes a fallback silently for
    /// a name it does not know, so this checks what each name resolves to rather than trusting that
    /// registration ran. Call after `FontRegistrar.registerBundledFonts()`.
    static func registered() -> QuranFaces {
        QuranFaces(available: Set(QuranFace.allCases.filter { face in
            let font = CTFontCreateWithName(face.postScriptName as CFString, 12, nil)
            return CTFontCopyPostScriptName(font) as String == face.postScriptName
        }))
    }

    /// The faces available in this process, resolved once. Registers the bundled fonts first —
    /// idempotent, so the answer does not depend on whether `App.init` or the container's
    /// initialiser reached the registrar first.
    static let launch: QuranFaces = {
        FontRegistrar.registerBundledFonts()
        return registered()
    }()

    func contains(_ face: QuranFace) -> Bool {
        available.contains(face)
    }

    /// `face` at a fixed size: Quran text sizes come from the page fit, not Dynamic Type. A face
    /// that did not register draws in the app's own face rather than CoreText's substitute.
    func font(_ face: QuranFace, size: CGFloat) -> Font {
        contains(face) ? .custom(face.postScriptName, fixedSize: size) : Self.chromeFont(size: size, weight: .regular)
    }

    /// `face` scaled with Dynamic Type like `style`: for Arabic in lists and titles, which are
    /// chrome; a page's own text keeps the page fit.
    func font(_ face: QuranFace, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        contains(face)
            ? .custom(face.postScriptName, size: size, relativeTo: style)
            : .custom(PlexAppFont.Weight.semiBold.postScriptName, size: size * 0.45, relativeTo: style)
    }

    /// The same face as a platform font, for measuring.
    func platformFont(_ face: QuranFace, size: CGFloat) -> PlatformFont {
        if contains(face), let font = PlatformFont(name: face.postScriptName, size: size) {
            return font
        }
        return .systemFont(ofSize: size)
    }

    /// The app's face (IBM Plex Sans Arabic) at a size the page fit chose — margin labels, and a
    /// surah header drawn without its QUL face. Fixed for the reason above. Where Plex itself did
    /// not register (a preview), CoreText falls back to the system face, which is readable.
    static func chromeFont(size: CGFloat, weight: Font.Weight) -> Font {
        .custom(PlexAppFont.Weight(weight).postScriptName, fixedSize: size)
    }
}

extension EnvironmentValues {
    /// Resolved once at launch by `AppContainer`; `unavailable` in previews, which draw the
    /// fallbacks.
    @Entry var quranFaces: QuranFaces = .unavailable
}
