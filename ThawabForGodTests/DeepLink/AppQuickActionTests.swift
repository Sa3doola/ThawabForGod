//
//  AppQuickActionTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The list on the app icon, and the one thing it must never do: silently lose an entry.
///
/// iOS shows four quick actions and drops the rest without saying so. `AppQuickAction.visible`
/// exists so that truncation is this app's decision rather than the system's, and this suite is
/// what keeps it one.
struct AppQuickActionTests {

    @Test func theVisibleListIsCappedAtWhatTheSystemShows() {
        #expect(AppQuickAction.visible.count <= AppQuickAction.maximumVisible)
    }

    /// Declaration order is display order. Anything else and reordering the enum — the intended
    /// way to promote an action into the four — would have no effect, or the wrong one.
    @Test func theVisibleListKeepsDeclarationOrder() {
        let expected = AppQuickAction.allCases.filter(\.isAvailable)
            .prefix(AppQuickAction.maximumVisible)

        #expect(AppQuickAction.visible == Array(expected))
    }

    @Test func onlyAvailableActionsAreOffered() {
        let unavailable = AppQuickAction.visible.filter { !$0.isAvailable }

        #expect(unavailable.isEmpty)
    }

    /// Every action has somewhere to go and something to draw. There is no `nil` route here the
    /// way `HomeShortcut` has one — a shortcut that opens nothing would be a dead entry on the
    /// reader's Home Screen, so an action that is not ready is `isAvailable == false` instead.
    @Test(arguments: AppQuickAction.allCases)
    func everyActionIsFullyFormed(_ action: AppQuickAction) {
        #expect(!action.symbol.isEmpty)
        #expect(!action.titleKey.rawValue.isEmpty)
        #expect(DeepLink(url: action.link.url) == action.link)
    }

    /// Two actions pointing at the same screen would spend two of four slots on one destination.
    @Test func noTwoActionsOpenTheSameScreen() {
        let links = Set(AppQuickAction.allCases.map(\.link))

        #expect(links.count == AppQuickAction.allCases.count)
    }

    // MARK: The wire format

    /// The item's `type` is the link's URL, and decoding it is how a tap gets back to a
    /// destination. This is the contract that has to survive a build: iOS caches shortcut items,
    /// so the string being decoded may have been written by a version of the app that is gone.
    @Test(arguments: AppQuickAction.allCases)
    func aRegisteredActionDecodesBackToItsDestination(_ action: AppQuickAction) {
        #if os(iOS)
        let type = action.link.url.absoluteString

        #expect(QuickActionsService.link(forType: type) == action.link)
        #endif
    }

    @Test func aTypeFromAnUnknownActionDecodesToNothing() {
        #if os(iOS)
        #expect(QuickActionsService.link(forType: "noor://something-else") == nil)
        #expect(QuickActionsService.link(forType: "") == nil)
        #expect(QuickActionsService.link(forType: "not a url at all") == nil)
        #endif
    }
}
