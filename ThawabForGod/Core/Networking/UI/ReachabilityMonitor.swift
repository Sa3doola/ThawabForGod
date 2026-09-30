//
//  ReachabilityMonitor.swift
//  ThawabForGod
//

import Network
import Observation

/// Tells the UI whether the network is currently usable, so online-only affordances can be
/// hidden or disabled. Nothing in the app should *wait* on this: core features work offline.
///
/// `NWPathMonitor` reports on its own queue; every update hops to the main actor before
/// touching observable state.
@Observable
@MainActor
final class ReachabilityMonitor {
    private(set) var isOnline: Bool = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.thawabforgod.reachability")
    @ObservationIgnored private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Weak at the outer closure, which is the one the monitor keeps — capturing weakly only
        // in the inner `Task` still left this handler holding `self` strongly. Rebound to a `let`
        // because a weak capture is a `var`, which a concurrently-running `Task` may not share;
        // the task holds it only until its one assignment is done.
        monitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            let owner = self
            Task { @MainActor in
                owner?.isOnline = isSatisfied
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        monitor.cancel()
    }

    deinit {
        monitor.cancel()
    }
}
