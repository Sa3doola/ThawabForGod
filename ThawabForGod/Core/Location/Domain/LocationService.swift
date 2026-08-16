//
//  LocationService.swift
//  ThawabForGod
//

import Foundation

/// Where the app stands with location permission.
///
/// Three cases, not CoreLocation's five: the app only ever asks for when-in-use, and every
/// flavour of "no" leads to the same fallback, so collapsing them keeps callers honest.
nonisolated enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

/// Why a location reading could not be produced.
nonisolated enum LocationError: Error, Equatable, Sendable {
    /// Permission was never granted, so there is nothing to read.
    case notAuthorized
    /// CoreLocation failed or timed out. The message is for logs, not for users.
    case unavailable(String)
}

/// Location permission and a one-shot coordinate reading.
///
/// Deliberately narrow. The app needs a point on the globe and nothing more — no continuous
/// tracking, no headings (Qibla will add that behind this same protocol), and no place names,
/// which would need the network and would break the offline promise.
///
/// `@MainActor` because `CLLocationManager` delivers its callbacks on the queue it was created
/// on, and this is UI-facing besides. Callers are already on the main actor.
@MainActor
protocol LocationService: AnyObject {
    var authorization: LocationAuthorization { get }

    /// Prompts for when-in-use access and resolves once the user has answered.
    ///
    /// Returns the resulting status rather than throwing: a refusal is an ordinary outcome
    /// this app is built to carry on from, not an error.
    @discardableResult
    func requestWhenInUseAuthorization() async -> LocationAuthorization

    /// A single reading of the device's position.
    func currentCoordinates() async throws -> Coordinates
}
