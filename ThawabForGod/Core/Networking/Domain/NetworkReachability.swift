//
//  NetworkReachability.swift
//  ThawabForGod
//

import Foundation

/// Whether the network is currently usable.
///
/// One property, and a protocol for it, because the concrete `ReachabilityMonitor` starts an
/// `NWPathMonitor` and reports what the machine running the test happens to be plugged into —
/// which is the one thing a test of "what does the app do offline?" cannot have.
///
/// **Nothing may wait on this.** It exists to let an online-only *affordance* stand down
/// gracefully — the city name on Home is the whole of its use today — never to gate a core
/// feature. See the architecture plan's first principle.
///
/// `@MainActor` because the monitor behind it publishes to observable state that views read.
@MainActor
protocol NetworkReachability: AnyObject {
    var isOnline: Bool { get }
}

extension ReachabilityMonitor: NetworkReachability {}
