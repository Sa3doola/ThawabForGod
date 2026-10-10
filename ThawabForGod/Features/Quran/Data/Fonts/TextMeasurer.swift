//
//  TextMeasurer.swift
//  ThawabForGod
//

import Foundation

#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
#endif

/// Text measurement with the platform's font type, on either platform.
///
/// Ported from Mushaf's `PlatformFont.swift` unchanged in behaviour (T13). `nonisolated` because
/// measuring one page takes thousands of calls and happens on `PageMetricsCache`'s detached task —
/// never on the main actor, which DEBUG builds enforce.
nonisolated enum TextMeasurer {
    /// Typographic width of `string` set in `font` on one line.
    static func width(of string: String, font: PlatformFont) -> CGFloat {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif
        return NSAttributedString(string: string, attributes: [.font: font]).size().width
    }

    /// A registered font by PostScript name (a page font), for measuring.
    static func font(named name: String, size: CGFloat) -> PlatformFont? {
        PlatformFont(name: name, size: size)
    }

    /// Height of one line of `font` (ascender + descender + leading).
    static func lineHeight(of font: PlatformFont) -> CGFloat {
        #if canImport(UIKit)
        font.lineHeight
        #else
        font.ascender - font.descender + font.leading
        #endif
    }
}
