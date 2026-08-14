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

        monitor.pathUpdateHandler = { path in
            let isSatisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = isSatisfied
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
