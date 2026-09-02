//
//  HomeLayoutTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// `HomeLayout` is four invariants wearing a struct, so these are organised by invariant rather
/// than by method. The forward-compatibility rule gets the most attention on purpose: it is the
/// one that has to hold across a release nobody has written yet.
struct HomeLayoutTests {

    // MARK: Helpers

    private func decode(_ json: String) throws -> HomeLayout {
        try JSONDecoder().decode(HomeLayout.self, from: Data(json.utf8))
    }

    /// A stored layout in the on-disk shape, so the fixtures below read like what is actually
    /// in `UserDefaults` rather than like a Swift value.
    private func stored(sections: [(String, Bool)], shortcuts: [(String, Bool)] = []) -> String {
        func entries(_ pairs: [(String, Bool)], key: String) -> String {
            pairs
                .map { #"{"\#(key)":"\#($0.0)","isVisible":\#($0.1)}"# }
                .joined(separator: ",")
        }

        return """
        {"sections":[\(entries(sections, key: "kind"))],\
        "shortcuts":[\(entries(shortcuts, key: "shortcut"))]}
        """
    }

    // MARK: The default

    /// Derived from `allCases`, so this pins the derivation rather than a hand-written list.
    @Test func theDefaultCoversEveryKindExactlyOnce() {
        let layout = HomeLayout.default

        #expect(layout.sections.map(\.kind) == HomeSectionKind.allCases)
        #expect(layout.shortcuts.map(\.shortcut) == HomeShortcut.allCases)
    }

    /// Derived from `isAvailable` rather than listed out, so shipping a reserved section moves
    /// this test's expectation with it instead of breaking it.
    @Test func theDefaultShowsEverythingThatIsBuilt() {
        let layout = HomeLayout.default

        #expect(layout.visibleSections == HomeSectionKind.allCases.filter(\.isAvailable))
        #expect(layout.visibleShortcuts == HomeShortcut.allCases.filter(\.isAvailable))
    }

    /// A reserved section is in the layout, out of the stack, and out of the editor — a switch
    /// that turns on nothing is worse than no switch.
    @Test func reservedSectionsAreNeitherDrawnNorOffered() {
        let layout = HomeLayout.default
        let reserved = HomeSectionKind.allCases.filter { !$0.isAvailable }

        #expect(reserved.isEmpty == false)

        for kind in reserved {
            #expect(layout.sections.map(\.kind).contains(kind))
            #expect(layout.visibleSections.contains(kind) == false)
            #expect(layout.editableSections.map(\.kind).contains(kind) == false)
            #expect(layout.canChangeVisibility(of: kind) == false)
        }
    }

    @Test func unavailableShortcutsAreNeitherDrawnNorOffered() {
        let layout = HomeLayout.default

        #expect(layout.visibleShortcuts.contains(.hadith) == false)
        #expect(layout.editableShortcuts.map(\.shortcut).contains(.hadith) == false)
        #expect(layout.canChangeVisibility(of: .hadith) == false)
    }

    // MARK: Rule 1 — the pinned section

    @Test func thePinnedSectionCannotBeHidden() {
        var layout = HomeLayout.default

        #expect(layout.canChangeVisibility(of: .nextPrayer) == false)

        layout.setVisibility(false, of: .nextPrayer)

        #expect(layout.isVisible(.nextPrayer))
        #expect(layout.visibleSections.first == .nextPrayer)
    }

    /// The editor marks the row undraggable, but nothing stops a *different* row being dropped
    /// above it — so the pin is re-asserted after every move.
    @Test func movingAnotherSectionAboveThePinPutsThePinBackFirst() {
        var layout = HomeLayout.default

        layout.moveSections(from: IndexSet(integer: 2), to: 0)

        #expect(layout.sections.first?.kind == .nextPrayer)
        #expect(
            layout.visibleSections
                == [.nextPrayer, .continueReading, .shortcuts, .lastActivity, .prayerTracker]
        )
    }

    @Test func draggingThePinItselfLeavesItWhereItWas() {
        var layout = HomeLayout.default

        layout.moveSections(from: IndexSet(integer: 0), to: 3)

        #expect(layout.visibleSections == HomeLayout.default.visibleSections)
    }

    @Test func aStoredLayoutThatHidesThePinIsRepaired() throws {
        let layout = try decode(
            stored(sections: [("shortcuts", true), ("lastActivity", true), ("nextPrayer", false)])
        )

        #expect(layout.sections.first?.kind == .nextPrayer)
        #expect(layout.isVisible(.nextPrayer))
    }

    @Test func aStoredLayoutMissingThePinGrowsItBack() throws {
        let layout = try decode(stored(sections: [("shortcuts", true), ("lastActivity", true)]))

        #expect(layout.sections.first?.kind == .nextPrayer)
        #expect(layout.isVisible(.nextPrayer))
    }

    // MARK: Rule 2 — the three-section floor

    @Test func hidingIsAllowedUntilTheFloorAndRefusedAtIt() {
        var layout = HomeLayout.default

        #expect(layout.visibleSections.count == 5)
        #expect(layout.canChangeVisibility(of: .continueReading))

        layout.setVisibility(false, of: .continueReading)
        layout.setVisibility(false, of: .prayerTracker)

        #expect(layout.visibleSections.count == HomeLayout.minimumVisibleSections)

        // At the floor every remaining toggle reports refusable *before* it is tapped, which is
        // what the editor disables the control on.
        #expect(layout.canChangeVisibility(of: .shortcuts) == false)
        #expect(layout.canChangeVisibility(of: .lastActivity) == false)

        layout.setVisibility(false, of: .shortcuts)

        #expect(layout.isVisible(.shortcuts))
        #expect(layout.visibleSections.count == HomeLayout.minimumVisibleSections)
    }

    /// Turning one back on is never refused — the floor is a floor, not a quota.
    @Test func showingASectionIsAlwaysAllowed() {
        var layout = HomeLayout.default
        layout.setVisibility(false, of: .continueReading)
        #expect(layout.visibleSections.count == 4)

        #expect(layout.canChangeVisibility(of: .continueReading))

        layout.setVisibility(true, of: .continueReading)

        #expect(layout.visibleSections.count == 5)
    }

    /// `setVisibility` will not let a user reach this state, but an older build or a withdrawn
    /// feature can leave it in the store, and an almost-empty Home is not how anyone should find
    /// that out.
    @Test func aStoredLayoutBelowTheFloorIsRefilledInDeclarationOrder() throws {
        let layout = try decode(
            stored(
                sections: HomeSectionKind.allCases.map { ($0.rawValue, $0.isPinned) }
            )
        )

        #expect(layout.visibleSections.count == HomeLayout.minimumVisibleSections)
        #expect(layout.visibleSections == [.nextPrayer, .shortcuts, .continueReading])
    }

    // MARK: Rule 3 — forward and backward compatibility

    /// The rule that makes shipping a new section a one-line change: a kind the stored array has
    /// never heard of is appended rather than treated as a decode failure.
    @Test func aKindTheStoredLayoutHasNeverSeenIsAppendedWithItsDefault() throws {
        let layout = try decode(
            stored(sections: [("nextPrayer", true), ("lastActivity", true), ("shortcuts", true)])
        )

        // What was stored keeps its order…
        #expect(layout.sections.prefix(3).map(\.kind) == [.nextPrayer, .lastActivity, .shortcuts])
        // …and everything else arrives behind it, in declaration order, at its default.
        #expect(
            layout.sections.dropFirst(3).map(\.kind)
                == HomeSectionKind.allCases.filter {
                    ![.nextPrayer, .lastActivity, .shortcuts].contains($0)
                }
        )
        #expect(layout.isVisible(.continueReading) == HomeSectionKind.continueReading.defaultVisibility)
    }

    /// The mirror of the rule above: a raw value that no longer maps to a case is dropped, and —
    /// the part that matters — it does not take the rest of the array with it.
    @Test func aRawValueThatNoLongerMapsToACaseIsDroppedNotThrown() throws {
        let layout = try decode(
            stored(
                sections: [("nextPrayer", true), ("moonPhase", true), ("shortcuts", false)],
                shortcuts: [("qibla", true), ("astrolabe", true)]
            )
        )

        #expect(layout.sections.count == HomeSectionKind.allCases.count)
        #expect(layout.shortcuts.count == HomeShortcut.allCases.count)
        // The known entry either side of the unknown one survived, with its stored visibility.
        #expect(layout.sections[1].kind == .shortcuts)
        #expect(layout.isVisible(.shortcuts) == false)
        #expect(layout.shortcuts.first?.shortcut == .qibla)
    }

    @Test func aDuplicatedKindCollapsesToItsFirstAppearance() throws {
        let layout = try decode(
            stored(sections: [("nextPrayer", true), ("shortcuts", false), ("shortcuts", true)])
        )

        #expect(layout.sections.filter { $0.kind == .shortcuts }.count == 1)
        #expect(layout.isVisible(.shortcuts) == false)
    }

    @Test func anEmptyStoredLayoutBecomesTheDefault() throws {
        #expect(try decode(#"{"sections":[],"shortcuts":[]}"#) == .default)
        #expect(try decode("{}") == .default)
    }

    @Test func encodingAndDecodingRoundTrips() throws {
        var layout = HomeLayout.default
        layout.setVisibility(false, of: .lastActivity)
        layout.moveSections(from: IndexSet(integer: 3), to: 1)
        layout.setVisibility(false, of: .qibla)
        layout.moveShortcuts(from: IndexSet(integer: 0), to: 3)

        let data = try JSONEncoder().encode(layout)

        #expect(try JSONDecoder().decode(HomeLayout.self, from: data) == layout)
    }

    /// A choice about a section that is not built yet has to survive the release that builds it —
    /// otherwise the reserved-case design buys nothing.
    @Test func aChoiceAboutAnUnavailableSectionIsPersisted() throws {
        let layout = try decode(
            stored(
                sections: HomeSectionKind.allCases.map { ($0.rawValue, $0 != .prayerTracker) }
            )
        )

        let data = try JSONEncoder().encode(layout)

        #expect(try JSONDecoder().decode(HomeLayout.self, from: data).isVisible(.prayerTracker) == false)
    }

    // MARK: Rule 4 — reset

    @Test func resetRestoresTheDefault() {
        var layout = HomeLayout.default
        layout.setVisibility(false, of: .lastActivity)
        layout.moveSections(from: IndexSet(integer: 1), to: 4)

        layout.reset()

        #expect(layout == .default)
    }

    // MARK: Reordering

    /// `onMove`'s destination is an index into the array *before* the removal, which is the part
    /// that is easy to get wrong — so this pins the semantics against a hand-worked example.
    @Test func movingDownwardsUsesTheOffsetSwiftUIWouldSend() {
        var layout = HomeLayout.default

        // Move `shortcuts` from second place to the end of the editable list.
        layout.moveSections(from: IndexSet(integer: 1), to: 5)

        #expect(
            layout.visibleSections
                == [.nextPrayer, .continueReading, .lastActivity, .prayerTracker, .shortcuts]
        )
    }

    @Test func movingSeveralRowsKeepsTheirRelativeOrder() {
        var layout = HomeLayout.default

        layout.moveSections(from: IndexSet([1, 2]), to: 5)

        #expect(
            layout.visibleSections
                == [.nextPrayer, .lastActivity, .prayerTracker, .shortcuts, .continueReading]
        )
    }

    /// Offsets index the *editable* list, so the reserved kinds are not something the caller has
    /// to know about — they are re-hung off the end, keeping their relative order.
    @Test func reorderingLeavesTheReservedKindsBehindTheEditableOnes() {
        var layout = HomeLayout.default

        layout.moveSections(from: IndexSet(integer: 1), to: 5)

        let reserved = layout.sections.map(\.kind).filter { !$0.isAvailable }
        #expect(reserved == HomeSectionKind.allCases.filter { !$0.isAvailable })
        #expect(layout.sections.suffix(reserved.count).map(\.kind) == reserved)
    }

    @Test func shortcutsReorderIndependentlyOfSections() {
        var layout = HomeLayout.default

        layout.moveShortcuts(from: IndexSet(integer: 3), to: 0)

        #expect(
            layout.visibleShortcuts == [.qibla, .morningAdhkar, .eveningAdhkar, .tasbih, .namesOfAllah]
        )
        #expect(layout.visibleSections == HomeLayout.default.visibleSections)
    }

    /// A tripwire rather than a behaviour test: the ceiling cannot be reached while there are
    /// fewer shortcuts than the cap, so the day a ninth is added this fails and asks for the real
    /// test to be written.
    @Test func theShortcutCeilingIsStillOutOfReach() {
        #expect(HomeShortcut.allCases.count <= HomeLayout.maximumVisibleShortcuts)
    }

    // MARK: Pairing

    /// The pinned card spans at every width, so it may never be dealt into half of one — see
    /// `HomeView.stack(width:)`, where a countdown in a half-width column is the failure the rule
    /// exists to prevent.
    @Test func thePinnedSectionNeverPairs() {
        #expect(!HomeSectionKind.pinned.canPair)
    }

    /// Only the short cards pair. The rest either already fill the width or are made of
    /// sentences, and half a width of sentence is truncation rather than density.
    @Test func onlyTheShortCardsPair() {
        let pairing = HomeSectionKind.allCases.filter(\.canPair)

        #expect(pairing == [.continueReading, .prayerTracker])
    }

    /// A section nobody can see yet cannot pair either — shipping one must not silently
    /// rearrange a Home screen somebody had settled on, which is the same rule
    /// `defaultVisibility` follows.
    @Test func noReservedSectionPairs() {
        for kind in HomeSectionKind.allCases where !kind.isAvailable {
            #expect(!kind.canPair, "\(kind) is reserved but pairs")
        }
    }
}
