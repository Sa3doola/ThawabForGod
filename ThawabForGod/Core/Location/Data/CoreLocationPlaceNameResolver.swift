//
//  CoreLocationPlaceNameResolver.swift
//  ThawabForGod
//

import CoreLocation
import Foundation

/// Reverse geocoding through CoreLocation.
///
/// An `actor` rather than a `@MainActor` class: this is the one piece of the location story that
/// waits on a server, and there is no reason for it to do that on the main actor. Being an actor
/// is also what makes the cache safe without a lock — `CLGeocoder` is not `Sendable`, and holding
/// it inside actor isolation is what keeps it from crossing anywhere it should not.
///
/// **Nothing is written to disk.** A resolved name is derived data, not a choice the user made,
/// and `SettingsStore`'s standing rule is that only chosen values are persisted. So the cache is
/// the process's, and a device that has been offline since launch simply shows no name — which is
/// what "cosmetic" has to mean if it means anything.
///
/// One entry is enough: the app tracks a single position, so a second slot would never be read.
/// The key is rounded to three decimals — about a hundred metres — because a live fix drifts by
/// metres constantly and an exact comparison would miss the cache on every reading.
actor CoreLocationPlaceNameResolver: PlaceNameResolving {
    private let geocoder = CLGeocoder()
    private var cached: (key: String, name: String)?

    func placeName(for coordinates: Coordinates) async -> String? {
        let key = Self.cacheKey(for: coordinates)

        if let cached, cached.key == key {
            return cached.name
        }

        let location = CLLocation(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )

        // `try?` rather than a mapped error: every failure here — offline, rate-limited, nothing
        // named at this point — has the same answer, and it is "draw the card without a name".
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let name = placemarks.first.flatMap(Self.name(from:)) else {
            return nil
        }

        cached = (key, name)
        return name
    }

    /// The narrowest name that is still recognisable, widening until something answers. At sea or
    /// in a desert `locality` is empty and the country is the honest answer.
    private static func name(from placemark: CLPlacemark) -> String? {
        placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.country
    }

    private static func cacheKey(for coordinates: Coordinates) -> String {
        String(format: "%.3f,%.3f", coordinates.latitude, coordinates.longitude)
    }
}
