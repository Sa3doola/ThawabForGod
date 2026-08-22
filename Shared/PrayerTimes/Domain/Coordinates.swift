//
//  Coordinates.swift
//  ThawabForGod
//

import Foundation

/// A point on the globe, in degrees. Deliberately not `CLLocationCoordinate2D`: Domain does
/// not import CoreLocation, and prayer times are computed from plain numbers.
nonisolated struct Coordinates: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// The Kaaba. Used as the app's placeholder location until the location slice lands, and
    /// as the fixed point every Qibla bearing is measured towards.
    static let makkah = Coordinates(latitude: 21.4225241, longitude: 39.8261818)
}
