//
//  AyahPanelLayoutTests.swift
//  ThawabForGodTests
//
//  The rule that decides where the ayah panel goes (a trailing column inside the reader, or a
//  sheet) and how wide the column is. Pure: the platform is a parameter, so the Mac's answer is
//  tested from the iOS simulator.
//

import CoreGraphics
import Testing
@testable import ThawabForGod

struct AyahPanelLayoutTests {
    // MARK: - Placement

    @Test func macAlwaysUsesTheSidePanel() {
        #expect(AyahPanelLayout.usesSidePanel(size: CGSize(width: 500, height: 800), isCompact: false, hasFold: false, platform: .macOS))
        #expect(AyahPanelLayout.usesSidePanel(size: CGSize(width: 1200, height: 800), isCompact: false, hasFold: false, platform: .macOS))
    }

    @Test func regularWidthLandscapeUsesTheSidePanel() {
        #expect(AyahPanelLayout.usesSidePanel(size: CGSize(width: 1100, height: 800), isCompact: false, hasFold: false, platform: .iOS))
    }

    @Test func regularWidthPortraitUsesASheet() {
        #expect(!AyahPanelLayout.usesSidePanel(size: CGSize(width: 800, height: 1100), isCompact: false, hasFold: false, platform: .iOS))
    }

    @Test func compactWidthUsesASheetEvenInLandscape() {
        #expect(!AyahPanelLayout.usesSidePanel(size: CGSize(width: 900, height: 400), isCompact: true, hasFold: false, platform: .iOS))
    }

    @Test func aVerticalFoldUsesTheSidePanelEvenAtCompactWidth() {
        #expect(AyahPanelLayout.usesSidePanel(size: CGSize(width: 900, height: 400), isCompact: true, hasFold: true, platform: .iOS))
    }

    @Test func anUnmeasuredContainerIsNeverASidePanel() {
        #expect(!AyahPanelLayout.usesSidePanel(size: .zero, isCompact: false, hasFold: false, platform: .iOS))
        #expect(!AyahPanelLayout.usesSidePanel(size: .zero, isCompact: false, hasFold: false, platform: .macOS))
    }

    // MARK: - Width

    @Test func widthIsThirtySixPercentOfTheContainer() {
        #expect(AyahPanelLayout.sidePanelWidth(containerWidth: 1000, fold: nil) == 360)
    }

    @Test func widthIsCappedAtTheMaximum() {
        #expect(AyahPanelLayout.sidePanelWidth(containerWidth: 2000, fold: nil) == 420)
    }

    @Test func widthHasAFloorOfTheMinimum() {
        #expect(AyahPanelLayout.sidePanelWidth(containerWidth: 700, fold: nil) == 320)
    }

    @Test func widthNeverExceedsHalfTheContainer() {
        #expect(AyahPanelLayout.sidePanelWidth(containerWidth: 500, fold: nil) == 250)
    }

    @Test func aFoldGivesTheTrailingHalfPlusItsGutter() {
        let fold = FoldGeometry(leadingWidth: 400, gutterWidth: 24, trailingWidth: 400)
        #expect(AyahPanelLayout.sidePanelWidth(containerWidth: 824, fold: fold) == 424)
    }
}
