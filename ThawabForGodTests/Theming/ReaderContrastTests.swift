//
//  ReaderContrastTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftUI
import Testing
@testable import ThawabForGod

/// Ported from Mushaf's ContrastTests (Phase 8.3): text colours meet WCAG AA (4.5:1) in all three
/// reader themes, on the page and on what is drawn behind the Arabic (the selection and the four
/// highlight shades). The palette now comes from the asset catalog rather than from literals.
@MainActor
struct ReaderContrastTests {
    private static func components(_ color: Color, scheme: ColorScheme = .light) -> (r: Double, g: Double, b: Double, a: Double) {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let resolved = color.resolve(in: environment)
        return (Double(resolved.linearRed), Double(resolved.linearGreen), Double(resolved.linearBlue), Double(resolved.opacity))
    }

    /// Relative luminance from linear components.
    private static func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    /// `color` composited over the opaque `background` as Core Graphics draws it: blended in
    /// gamma-encoded sRGB, returned as linear components.
    private static func over(_ color: Color, _ background: Color, scheme: ColorScheme = .light) -> (r: Double, g: Double, b: Double) {
        let f = components(color, scheme: scheme), b = components(background, scheme: scheme)
        func blend(_ x: Double, _ y: Double) -> Double { linear(encoded(x) * f.a + encoded(y) * (1 - f.a)) }
        return (blend(f.r, b.r), blend(f.g, b.g), blend(f.b, b.b))
    }

    private static func encoded(_ c: Double) -> Double { c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055 }
    private static func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }

    static func ratio(_ foreground: Color, on background: (r: Double, g: Double, b: Double), scheme: ColorScheme = .light) -> Double {
        let f = components(foreground, scheme: scheme)
        let lf = luminance((f.r, f.g, f.b)), lb = luminance(background)
        return (max(lf, lb) + 0.05) / (min(lf, lb) + 0.05)
    }

    @Test(arguments: ReaderTheme.allCases)
    func readerTextIsLegible(theme: ReaderTheme) {
        let p = ReadingPalette(theme: theme)
        let page = Self.over(p.background, p.background)
        #expect(Self.ratio(p.text, on: page) >= 7, "Quran and translation text (AAA)")
        #expect(Self.ratio(p.secondaryText, on: page) >= 4.5, "secondary text")
        #expect(Self.ratio(p.ornament, on: page) >= 4.5, "margin labels (juz, hizb, sajdah) are drawn in the ornament colour")
        #expect(Self.ratio(p.text, on: Self.over(p.selection, p.background)) >= 4.5, "text on the selection")
        for color in HighlightColor.allCases {
            #expect(Self.ratio(p.text, on: Self.over(p.highlight(color), p.background)) >= 4.5, "text on the \(color) highlight")
        }
    }

    /// A reader theme is fixed, not light-and-dark: the page colours carry one value for both
    /// appearances, so choosing Sepia for the evening does not change when the system flips.
    @Test(arguments: ReaderTheme.allCases)
    func colorsAreFixedAcrossAppearances(theme: ReaderTheme) {
        let p = ReadingPalette(theme: theme)
        let colors = [p.background, p.text, p.secondaryText, p.ornament]
        for color in colors {
            let light = Self.components(color, scheme: .light)
            let dark = Self.components(color, scheme: .dark)
            #expect([light.r, light.g, light.b, light.a] == [dark.r, dark.g, dark.b, dark.a])
        }
    }
}
