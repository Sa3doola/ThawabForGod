//
//  TipsServiceTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftUI // `Text`; MEMBER_IMPORT_VISIBILITY means TipKit does not re-export it
import Testing
import TipKit
@testable import ThawabForGod

/// `.serialized` for the same reason the networking suite is: TipKit's datastore is
/// process-wide state, and two tests resetting it in parallel would see each other's writes.
@MainActor
@Suite(.serialized)
struct TipsServiceTests {

    /// A tip with no rules at all, so eligibility is decided purely by what the service does
    /// to it. The real tips are gated on donations and parameters, which would make every
    /// assertion below vacuously true.
    ///
    /// The id is per-instance rather than fixed because TipKit's datastore is process-wide and
    /// `Tips.resetDatastore()` does not take effect within a session — a fixed id would come
    /// back still invalidated the second time the suite runs in the same process.
    private nonisolated struct UnconditionalTip: Tip {
        let id = "tests_unconditional_\(UUID().uuidString)"
        var title: Text { Text(verbatim: "Test") }
    }

    /// A datastore of this test's own, so a run never disturbs the app's real one.
    private func makeService() -> TipsService {
        TipsService(
            datastoreURL: FileManager.default.temporaryDirectory
                .appending(path: "TipsServiceTests", directoryHint: .isDirectory)
        )
    }

    /// Waits for a tip's status to settle on `expected`, and reports whatever it ended on.
    ///
    /// TipKit updates `status` asynchronously — read straight after a write it still reports
    /// the *previous* value, which is why the framework publishes `statusUpdates` at all. A
    /// bounded poll rather than `statusUpdates` because a stream that never emits the awaited
    /// value would hang the suite; this fails in a couple of seconds with the status it
    /// actually saw, and costs a passing run only the one poll interval.
    private func settledStatus(
        of tip: some Tip,
        expecting expected: Tips.Status
    ) async -> Tips.Status {
        for _ in 0..<100 {
            if tip.status == expected { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return tip.status
    }

    @Test func configuringOpensTheDatastore() {
        let service = makeService()

        service.configure()

        #expect(TipsService.isConfigured)
    }

    /// `Tips.configure` is one-shot per process and throws on a second call, so the guard
    /// inside the service — not the caller — has to be the thing that holds.
    @Test func configuringTwiceIsHarmless() {
        makeService().configure()
        makeService().configure()

        #expect(TipsService.isConfigured)
    }

    @Test func resettingBeforeConfigurationDoesNothing() {
        // Not `makeService().configure()` first: this is the path where the datastore failed
        // to open, and reaching into it anyway is what would throw.
        makeService().resetAll()
    }

    /// Reaching TipKit at all is what this proves — the service's only job is to pass the
    /// reason through, and a tip nothing has retired must not report itself retired.
    @Test func invalidatingRetiresATip() async {
        let service = makeService()
        service.configure()

        let tip = UnconditionalTip()
        #expect(await settledStatus(of: tip, expecting: .available) == .available)

        service.invalidate(tip, reason: .tipClosed)

        #expect(await settledStatus(of: tip, expecting: .invalidated(.tipClosed)) == .invalidated(.tipClosed))
        #expect(tip.shouldDisplay == false)
    }

    /// Only that the call reaches TipKit and the service stays usable afterwards.
    ///
    /// Deliberately not asserting that a retired tip comes back or that donations disappear:
    /// measured on this SDK, neither happens inside the session that calls it — see the note
    /// on `TipsService.resetAll()`.
    @Test func resettingAfterConfigurationCallsThrough() async {
        let service = makeService()
        service.configure()
        await HomeTipEvents.opened.donate()

        service.resetAll()

        #expect(TipsService.isConfigured)
    }
}
