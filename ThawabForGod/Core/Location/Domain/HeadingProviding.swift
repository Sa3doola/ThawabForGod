//
//  HeadingProviding.swift
//  ThawabForGod
//

import Foundation

/// One reading of where the top of the device is pointing.
///
/// Deliberately not `CLHeading`: Domain does not import CoreLocation, and a compass needle
/// only ever needs two numbers.
nonisolated struct DeviceHeading: Equatable, Sendable {
    /// Degrees clockwise from **true** north — the same reference the Qibla bearing uses, so
    /// the two can be subtracted directly.
    let trueHeading: Double

    /// The largest plausible error in `trueHeading`, in degrees. Negative when the reading is
    /// invalid, which is CoreLocation's convention and worth preserving rather than papering
    /// over: "unknown" and "accurate to 0°" are not the same answer.
    let accuracy: Double

    /// Beyond this, the system compass asks to be calibrated, so the app says so too.
    static let calibrationThreshold: Double = 20

    var isReliable: Bool {
        accuracy >= 0 && accuracy <= Self.calibrationThreshold
    }
}

/// A live feed of the device's heading, and whether this device can produce one at all.
///
/// Separate from `LocationService` because the two answer different questions and, more to the
/// point, are available on different hardware: every platform the app ships on can produce a
/// position, but only a device with a magnetometer can produce a heading. Keeping them apart
/// is what lets the Qibla screen degrade to a static readout on a Mac without pretending the
/// location half failed.
///
/// `@MainActor` for the same reason as `LocationService`: `CLLocationManager` delivers on the
/// queue it was created on, and every consumer here is a view.
@MainActor
protocol HeadingProviding: AnyObject {
    /// Whether this device has a compass. `false` on macOS and on iPads without a
    /// magnetometer — a fact about the hardware, not a failure.
    var isHeadingAvailable: Bool { get }

    /// Headings until the consuming task is cancelled.
    ///
    /// An `AsyncStream` rather than a delegate or a callback: it makes the feed's lifetime the
    /// task's lifetime, so a `.task` that SwiftUI tears down also stops the magnetometer, with
    /// no `stop()` for a caller to forget. Returns an already-finished stream when there is no
    /// compass, so callers never have to branch before iterating.
    func headingUpdates() -> AsyncStream<DeviceHeading>
}
