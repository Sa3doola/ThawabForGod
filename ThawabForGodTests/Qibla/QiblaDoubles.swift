//
//  QiblaDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// A heading feed the test drives by hand.
///
/// The stream is real — this is the same `AsyncStream` the view model consumes in production —
/// but nothing yields until `send(_:)` is called, so a test can place the compass at an exact
/// angle instead of waiting on hardware.
@MainActor
final class StubHeadingProvider: HeadingProviding {
    var isHeadingAvailable: Bool

    private(set) var subscriptionCount = 0
    private(set) var isFinished = false

    private var continuation: AsyncStream<DeviceHeading>.Continuation?

    init(isHeadingAvailable: Bool = true) {
        self.isHeadingAvailable = isHeadingAvailable
    }

    func headingUpdates() -> AsyncStream<DeviceHeading> {
        subscriptionCount += 1

        guard isHeadingAvailable else {
            return AsyncStream { $0.finish() }
        }

        let (stream, continuation) = AsyncStream<DeviceHeading>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.isFinished = true }
        }
        self.continuation = continuation

        return stream
    }

    func send(_ heading: DeviceHeading) {
        continuation?.yield(heading)
    }

    func finish() {
        continuation?.finish()
    }
}

/// A prayer-time engine that answers one fixed bearing.
///
/// The point of the double: the needle maths and the spherical trigonometry fail in different
/// ways, and a view-model test that depended on real astronomy could not tell them apart.
nonisolated struct StubQiblaEngine: PrayerTimeCalculating {
    var bearing: Double

    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule {
        // Nothing here asks for prayer times; answering would only invite a test to rely on it.
        throw PrayerTimeError.notComputable(date)
    }

    func qiblaBearing(from coordinates: Coordinates) -> Double {
        bearing
    }
}

extension QiblaInfo {
    static func stub(
        coordinates: Coordinates = Coordinates(latitude: 51.5074, longitude: -0.1278),
        direction: Double = 118.987,
        distanceToKaaba: Double = 4_793_000
    ) -> QiblaInfo {
        QiblaInfo(coordinates: coordinates, direction: direction, distanceToKaaba: distanceToKaaba)
    }
}

extension DeviceHeading {
    /// Reliable by default — the accuracy only matters to the calibration tests.
    static func stub(_ trueHeading: Double, accuracy: Double = 5) -> DeviceHeading {
        DeviceHeading(trueHeading: trueHeading, accuracy: accuracy)
    }
}
