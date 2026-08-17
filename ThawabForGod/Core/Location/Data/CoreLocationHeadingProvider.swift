//
//  CoreLocationHeadingProvider.swift
//  ThawabForGod
//

import CoreLocation
import Foundation

/// `CLLocationManager`'s heading feed behind `HeadingProviding`.
///
/// The whole CoreLocation half is `#if os(iOS)`: `startUpdatingHeading()` and
/// `headingAvailable()` simply do not exist on macOS, so there is no Mac code path to write —
/// `isHeadingAvailable` answers `false` and `headingUpdates()` hands back a finished stream.
/// The Qibla screen treats that as a first-class state rather than an error.
///
/// The delegate-to-`AsyncStream` bridge is the reason this type exists. Above it, the feed is
/// an ordinary `for await` loop whose lifetime is the consuming task's, which is what removes
/// every "who calls stop?" question from the feature.
@MainActor
final class CoreLocationHeadingProvider: NSObject, HeadingProviding {
    #if os(iOS)
    private let manager = CLLocationManager()

    /// One continuation per live consumer, keyed so a terminating stream can remove exactly
    /// its own. A dictionary rather than a single continuation because the screen may be
    /// rebuilt while the old task is still winding down, and the newer consumer must not be
    /// silently replaced by the older one's teardown.
    private var subscribers: [UUID: AsyncStream<DeviceHeading>.Continuation] = [:]
    #endif

    override init() {
        super.init()
        #if os(iOS)
        manager.delegate = self
        // Coarse on purpose, matching `CoreLocationService`: the position here exists only so
        // CoreLocation can resolve true north, and declination does not vary within a city.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        #endif
    }

    var isHeadingAvailable: Bool {
        #if os(iOS)
        CLLocationManager.headingAvailable()
        #else
        false
        #endif
    }

    func headingUpdates() -> AsyncStream<DeviceHeading> {
        #if os(iOS)
        guard isHeadingAvailable else { return .finished }

        let id = UUID()
        // `.bufferingNewest(1)` because a heading is a *current* value, not an event log: a
        // consumer that falls behind wants where the device is pointing now, and replaying a
        // queue of stale angles would make the needle swing through history.
        let (stream, continuation) = AsyncStream<DeviceHeading>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        continuation.onTermination = { [weak self] _ in
            // Runs wherever the stream ended — usually the cancellation of the consuming task,
            // off this actor — so the hop back is mandatory, not defensive. Unwrapped before
            // the `Task` rather than inside it: `self?` there would capture the weak *variable*
            // in concurrently-executing code, which Swift 6 rejects outright.
            guard let self else { return }
            Task { @MainActor in self.removeSubscriber(id) }
        }

        subscribers[id] = continuation
        startIfNeeded()

        return stream
        #else
        return .finished
        #endif
    }

    #if os(iOS)
    private func startIfNeeded() {
        guard subscribers.count == 1 else { return }

        // Location updates alongside the heading, and not by accident: `CLHeading.trueHeading`
        // is only valid while CoreLocation knows where the device is, because true north is
        // magnetic north corrected by the local declination. Without this the reading below
        // falls back to magnetic, which is off by up to ~20° in parts of the world.
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)

        // The magnetometer and the GPS both stop the moment nobody is looking at the screen.
        guard subscribers.isEmpty else { return }
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }
    #endif
}

// MARK: - CLLocationManagerDelegate

#if os(iOS)
extension CoreLocationHeadingProvider: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = DeviceHeading(newHeading)
        for continuation in subscribers.values {
            continuation.yield(heading)
        }
    }

    /// iOS draws the calibration overlay itself; all this decides is whether to let it.
    /// Answering `true` while the reading is poor is what makes the "wave the device" prompt
    /// appear, which is the only way a user can actually fix a bad compass.
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        guard let heading = manager.heading else { return true }
        return !DeviceHeading(heading).isReliable
    }

    /// A failed heading is not worth surfacing: the last good reading stays on screen and the
    /// next update supersedes it. Location failures matter to `CoreLocationService`, not here.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}

// MARK: - CoreLocation to domain

nonisolated private extension DeviceHeading {
    init(_ heading: CLHeading) {
        // `trueHeading` is negative until CoreLocation has a position to derive the local
        // declination from. Magnetic north is the honest fallback — the needle stays useful,
        // just off by the declination. V1 deliberately does not correct for that: doing it
        // properly means shipping and updating a world magnetic model, and doing it roughly
        // would be a made-up number dressed as a correction.
        let resolved = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        self.init(trueHeading: resolved, accuracy: heading.headingAccuracy)
    }
}
#endif

// MARK: - Finished stream

nonisolated private extension AsyncStream {
    /// A stream that ends before it yields anything, so a caller with no compass can still
    /// write `for await` without a branch.
    static var finished: AsyncStream<Element> {
        AsyncStream { $0.finish() }
    }
}
