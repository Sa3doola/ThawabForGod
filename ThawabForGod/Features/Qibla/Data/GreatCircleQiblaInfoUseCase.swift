//
//  GreatCircleQiblaInfoUseCase.swift
//  ThawabForGod
//

import CoreLocation
import Foundation

/// The Qibla, from the same engine that computes prayer times.
///
/// It owns no astronomy. The bearing comes from `PrayerTimeCalculating`, which is Adhan behind
/// a protocol, so there is exactly one implementation of the Qibla formula in the app rather
/// than a second copy that quietly disagrees with the first.
///
/// In `Data`, not `Domain`, because of the `CoreLocation` import below: Domain stays pure
/// Swift, and this is the layer where a framework is allowed to be the answer.
nonisolated struct GreatCircleQiblaInfoUseCase: GetQiblaInfoUseCase {
    private let engine: any PrayerTimeCalculating

    init(engine: any PrayerTimeCalculating) {
        self.engine = engine
    }

    func qiblaInfo(for coordinates: Coordinates) -> QiblaInfo {
        QiblaInfo(
            coordinates: coordinates,
            direction: engine.qiblaBearing(from: coordinates),
            distanceToKaaba: coordinates.distance(to: .makkah)
        )
    }
}

// MARK: - Great-circle distance

nonisolated private extension Coordinates {
    /// Metres along the surface, via `CLLocation`.
    ///
    /// Foundation has no geodesic, and a hand-rolled haversine would assume a sphere;
    /// `CLLocation.distance(from:)` measures on the WGS-84 ellipsoid, which is the same figure
    /// every map application quotes. It is pure arithmetic — no location services are started
    /// by constructing a `CLLocation`.
    func distance(to other: Coordinates) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
