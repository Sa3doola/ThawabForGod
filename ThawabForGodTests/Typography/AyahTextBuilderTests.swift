//
//  AyahTextBuilderTests.swift
//  ThawabForGodTests
//

import SwiftUI
import Testing
@testable import ThawabForGod

/// The verse-and-medallion paragraph.
///
/// The property worth pinning is the exception to the numbers rule: the marker run must be ASCII
/// digits, because the medallion faces draw by a ligature over exactly those. An Arabic-Indic
/// digit slipping in — from a well-meaning pass that routed it through `LocalizationManager` —
/// would draw a bare numeral with no ring around it, on every verse.
struct AyahTextBuilderTests {

    private let markerFont = AyahMarkerStyle.style3.font(size: 17)

    @Test func theWordsComeFirstThenTheMarker() {
        let text = AyahTextBuilder.text("ٱللَّهُ", number: 255, markerFont: markerFont)

        #expect(String(text.characters) == "ٱللَّهُ" + AyahTextBuilder.separator + "255")
    }

    @Test func onlyTheMarkerCarriesAFont() {
        let text = AyahTextBuilder.text("ٱللَّهُ", number: 255, markerFont: markerFont)

        let marked = text.runs.filter { $0.font != nil }
        #expect(marked.count == 1)
        #expect(marked.first.map { String(text[$0.range].characters) } == "255")
    }

    @Test(arguments: [1, 7, 99, 286])
    func theMarkerIsAsciiDigitsOnly(number: Int) {
        let text = AyahTextBuilder.text("قُلْ", number: number, markerFont: markerFont)

        let marker = text.runs.filter { $0.font != nil }.map { String(text[$0.range].characters) }
        let scalars = marker.joined().unicodeScalars

        #expect(!scalars.isEmpty)
        #expect(scalars.allSatisfy { ("0"..."9").contains($0) })
    }

    @Test func withNoNumberItIsTheWordsAlone() {
        let text = AyahTextBuilder.text("قُلْ", number: nil, markerFont: markerFont)

        #expect(String(text.characters) == "قُلْ")
        #expect(text.runs.allSatisfy { $0.font == nil })
    }
}
