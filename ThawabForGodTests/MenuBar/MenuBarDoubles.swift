//
//  MenuBarDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// A login item that answers whatever the test says, and remembers what it was asked.
///
/// A fake rather than the real `SMAppService`, and this is the one place in the suite where that
/// is not merely convenient: registering a login item changes the user's machine, survives the
/// test run, and would make the app start at every login on whoever's Mac ran it.
@MainActor
final class FakeLaunchAtLogin: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus
    var enableError: (any Error)?
    var disableError: (any Error)?

    private(set) var enableCount = 0
    private(set) var disableCount = 0
    private(set) var openedSystemSettings = false

    /// What `enable()` leaves the status as when it succeeds. `requiresApproval` is the case
    /// worth being able to simulate: registration succeeded, and the switch still is not on.
    var statusAfterEnable: LaunchAtLoginStatus = .enabled

    /// `nonisolated` so it can be a default argument. `LaunchAtLoginServicing` is a `@MainActor`
    /// protocol, which makes this class main-actor isolated — and a default argument is evaluated
    /// in a nonisolated context, so a plain `init` could not appear in one.
    nonisolated init(status: LaunchAtLoginStatus = .disabled) {
        self.status = status
    }

    func enable() throws {
        enableCount += 1
        if let enableError { throw enableError }
        status = statusAfterEnable
    }

    func disable() throws {
        disableCount += 1
        if let disableError { throw disableError }
        status = .disabled
    }

    func openSystemSettings() {
        openedSystemSettings = true
    }
}

struct LoginItemError: Error {}
