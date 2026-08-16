//
//  TipReportingDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// Records what Home reported to TipKit, so the rule inputs can be asserted without opening a
/// datastore — a real donation would need `Tips.configure` and would leak between test runs.
///
/// Locked rather than actor-isolated, and so `@unchecked Sendable`: `countingDownToTomorrow`
/// is a synchronous `nonisolated` requirement, which no actor could witness. The invariant the
/// lock upholds is the whole of it — every access to the two counters goes through it.
nonisolated final class SpyHomeTipReporter: HomeTipReporting, @unchecked Sendable {
    private let lock = NSLock()
    private var openCount = 0
    private var rollover: Bool?

    /// How many appearances of Home have been donated.
    var opens: Int {
        lock.withLock { openCount }
    }

    /// The last reported value, or `nil` if nothing has been reported yet — which is worth
    /// distinguishing from a reported `false`.
    var isCountingDownToTomorrow: Bool? {
        lock.withLock { rollover }
    }

    func homeOpened() async {
        lock.withLock { openCount += 1 }
    }

    func countingDownToTomorrow(_ isCountingDown: Bool) {
        lock.withLock { rollover = isCountingDown }
    }
}

/// The onboarding equivalent. See `SpyHomeTipReporter` for the `@unchecked Sendable` invariant.
nonisolated final class SpyOnboardingTipReporter: OnboardingTipReporting, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var completions: Int {
        lock.withLock { count }
    }

    func onboardingCompleted() {
        lock.withLock { count += 1 }
    }
}
