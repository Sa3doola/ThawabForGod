//
//  CoreLocationService.swift
//  ThawabForGod
//

import CoreLocation
import Foundation

/// `CLLocationManager` behind the `LocationService` protocol.
///
/// CoreLocation is confined to `Core/Location/Data` — this file and
/// `CoreLocationHeadingProvider` — for the same reason `PrayerTimeEngine` is the only file that
/// imports Adhan: the delegate-and-callback shape stops here, and everything above sees `async`
/// functions and streams carrying domain values.
///
/// Accuracy is deliberately coarse. Prayer times and the Qibla shift by seconds and fractions
/// of a degree over a kilometre, so asking for a precise fix would spend battery and privacy
/// on precision nobody sees.
/// It is also the app's single **writer** of the last-known position, and that is deliberate
/// rather than incidental. Every live fix in the app comes through `currentCoordinates()`, so
/// recording here means no call site anywhere has to remember to — and there is exactly one
/// place to look when the cached position is wrong. What reads it back is a widget or a
/// reminder, neither of which may ask CoreLocation for itself; see
/// `SettingsStore.bestKnownCoordinates`.
@MainActor
final class CoreLocationService: NSObject, LocationService {
    private let manager: CLLocationManager
    private let settingsStore: any SettingsStore

    private var authorizationRequest: CheckedContinuation<LocationAuthorization, Never>?
    private var coordinatesRequest: CheckedContinuation<Coordinates, Error>?

    init(settingsStore: any SettingsStore) {
        manager = CLLocationManager()
        self.settingsStore = settingsStore
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorization: LocationAuthorization {
        LocationAuthorization(manager.authorizationStatus)
    }

    @discardableResult
    func requestWhenInUseAuthorization() async -> LocationAuthorization {
        // Asking again once the user has answered does nothing — iOS shows the prompt once —
        // so report the standing answer rather than hanging on a callback that never comes.
        guard authorization == .notDetermined else {
            return authorization
        }

        // A second caller would strand the first continuation, which is a crash in debug.
        resumeAuthorizationRequest(with: authorization)

        return await withCheckedContinuation { continuation in
            authorizationRequest = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentCoordinates() async throws -> Coordinates {
        guard authorization == .authorized else {
            throw LocationError.notAuthorized
        }

        resumeCoordinatesRequest(with: .failure(LocationError.unavailable("superseded by a newer request")))

        return try await withCheckedThrowingContinuation { continuation in
            coordinatesRequest = continuation
            manager.requestLocation()
        }
    }

    // MARK: Continuation bookkeeping

    private func resumeAuthorizationRequest(with status: LocationAuthorization) {
        guard let request = authorizationRequest else { return }
        authorizationRequest = nil
        request.resume(returning: status)
    }

    private func resumeCoordinatesRequest(with result: Result<Coordinates, Error>) {
        // Recorded whether or not anybody is still waiting for it. A request superseded by a
        // newer one still produced a real reading, and the cache is about where the device is
        // rather than about who asked.
        if case .success(let coordinates) = result {
            settingsStore.recordLastKnown(coordinates)
        }

        guard let request = coordinatesRequest else { return }
        coordinatesRequest = nil
        request.resume(with: result)
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // This also fires once when the delegate is first assigned, while the status is still
        // undetermined and no request is outstanding — hence both guards.
        guard authorization != .notDetermined else { return }
        resumeAuthorizationRequest(with: authorization)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            resumeCoordinatesRequest(with: .failure(LocationError.unavailable("no location in update")))
            return
        }

        resumeCoordinatesRequest(
            with: .success(
                Coordinates(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        resumeCoordinatesRequest(with: .failure(LocationError.unavailable(error.localizedDescription)))
    }
}

// MARK: - CoreLocation to domain

nonisolated private extension LocationAuthorization {
    /// Every flavour of refusal collapses to `.denied`: the app's response is the same for a
    /// user who said no and for one whose device policy said it for them.
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .authorizedWhenInUse, .authorizedAlways:
            self = .authorized
        case .denied, .restricted:
            self = .denied
        @unknown default:
            self = .denied
        }
    }
}
