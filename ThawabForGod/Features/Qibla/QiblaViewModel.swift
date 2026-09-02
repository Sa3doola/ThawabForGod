//
//  QiblaViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the Qibla screen: where the Kaaba is, where the device is pointing, and which of the
/// two the screen is currently able to show.
///
/// The interesting design decision here is that **an absent compass is not an error**. A Mac
/// and an iPad without a magnetometer can still be told the exact bearing and distance — they
/// just cannot animate a needle — so the screen degrades to a static readout rather than
/// showing a failure for hardware the user was never going to have.
@Observable
@MainActor
final class QiblaViewModel {

    /// What the screen can show right now.
    ///
    /// `permissionDenied` means *there is no position to work from and manual entry is the way
    /// out* — which also covers a granted permission that never yielded a fix, because the
    /// remedy the user is offered is identical in both cases.
    enum Status: Equatable {
        /// Still asking for, or waiting on, a position.
        case locating
        /// Live compass, trustworthy reading.
        case ready
        /// Live compass, but the magnetometer wants waving about. iOS puts its own calibration
        /// overlay up; this is the in-app hint that goes with it.
        case needsCalibration
        /// No position. The manual-entry fallback is the way forward.
        case permissionDenied
        /// No magnetometer on this device — bearing and distance only, and that is fine.
        case headingUnavailable

        /// Whether the dial and needle belong on screen at all.
        var showsLiveCompass: Bool {
            self == .ready || self == .needsCalibration
        }

        /// Whether there is a position worth printing under the dial.
        var showsReadout: Bool {
            self != .locating && self != .permissionDenied
        }
    }

    // MARK: State

    /// The resolved position, bearing and distance — one value, so the readout and the needle
    /// can never disagree about which point they describe.
    private(set) var info: QiblaInfo?

    /// Degrees clockwise from true north that the device is pointing.
    ///
    /// Its own stored property, apart from `info` and from `isHeadingReliable`, for the reason
    /// `HomeViewModel.countdown` is: Observation tracks reads per property, so a value that
    /// changes many times a second only invalidates the views that actually read it — the dial
    /// and the needle — and leaves the readout alone.
    private(set) var deviceHeading: Double = 0

    /// Whether the last reading was accurate enough to trust. Separate from `deviceHeading`
    /// because it changes almost never, and `status` reads it.
    private(set) var isHeadingReliable = true

    /// Whether the device is being held pointing at the Kaaba.
    ///
    /// Its own stored property rather than a computed one over `deviceHeading`, and that is the
    /// point of the whole feature: a computed answer would change with every reading, and the
    /// screen turns this into a ring and a haptic — things that must fire on the *crossing*, not
    /// on the angle. Stored, guarded, and written only when it actually flips.
    private(set) var isAlignedWithQibla = false

    /// Whether the attempt to find the user has finished, however it went. Without it, "no
    /// position yet" and "no position, and there will not be one" look the same.
    private(set) var hasAttemptedPosition = false

    /// Raw text from the manual-entry fields, kept as typed so a half-finished number survives
    /// the next keystroke. Parsed on submit, exactly as onboarding does it.
    var manualLatitude = ""
    var manualLongitude = ""

    @ObservationIgnored private let getQiblaInfo: any GetQiblaInfoUseCase
    @ObservationIgnored private let locationService: any LocationService
    @ObservationIgnored private let headingProvider: any HeadingProviding

    /// - Parameter coordinates: a position already known at construction — onboarding's, in
    ///   practice — so the screen has a bearing before the first fix arrives. Deliberately
    ///   optional with no Makkah fallback: unlike prayer times, a Qibla computed from a made-up
    ///   position is worse than no Qibla at all.
    init(
        getQiblaInfo: any GetQiblaInfoUseCase,
        locationService: any LocationService,
        headingProvider: any HeadingProviding,
        coordinates: Coordinates? = nil
    ) {
        self.getQiblaInfo = getQiblaInfo
        self.locationService = locationService
        self.headingProvider = headingProvider

        if let coordinates {
            self.info = getQiblaInfo.qiblaInfo(for: coordinates)
        }
    }

    // MARK: Derived

    /// Derived rather than stored, so no ordering of the two async steps — finding the user and
    /// receiving the first heading — can leave the screen in a state that contradicts what it
    /// already knows.
    var status: Status {
        guard info != nil else {
            return hasAttemptedPosition ? .permissionDenied : .locating
        }
        guard headingProvider.isHeadingAvailable else {
            return .headingUnavailable
        }
        return isHeadingReliable ? .ready : .needsCalibration
    }

    var qiblaDirection: Double { info?.direction ?? 0 }

    var distanceToKaaba: Double { info?.distanceToKaaba ?? 0 }

    var coordinates: Coordinates? { info?.coordinates }

    /// How far to rotate the arrow so it points at the Kaaba.
    ///
    /// The bearing is fixed relative to true north; the device is not. Subtracting one from the
    /// other converts "where the Kaaba is" into "where to draw the arrow on this screen", and
    /// normalising keeps it a rotation rather than a signed offset.
    var needleRotation: Double {
        Self.normalized(qiblaDirection - deviceHeading)
    }

    /// Folds any angle into `0..<360`.
    static func normalized(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    // MARK: Alignment

    /// How far the needle is from straight ahead, in degrees — `0` facing the Kaaba, `180`
    /// directly away from it.
    ///
    /// The *shorter* way round the dial, which is the only reading that makes sense to compare
    /// against a tolerance: a needle at 359° is one degree off, not three hundred and fifty-nine.
    var alignmentOffset: Double {
        let rotation = needleRotation
        return min(rotation, 360 - rotation)
    }

    /// Close enough to say the phone is facing the Kaaba.
    static let alignmentTolerance: Double = 5

    /// Far enough to say it no longer is.
    ///
    /// **Two thresholds rather than one, and the gap between them is the feature.** On a single
    /// boundary a hand resting at exactly five degrees does not hold still — it crosses back and
    /// forth several times a second, and here every crossing is a ring appearing and a haptic
    /// firing. Widening the exit turns that into one bump on arrival and one clean release when
    /// the user genuinely turns away, which is what a physical detent does.
    static let alignmentRelease: Double = 9

    /// Recomputes `isAlignedWithQibla` from the latest reading.
    ///
    /// **Alignment is a claim, so it is only made where the claim can be supported.** No
    /// position means no bearing to be aligned with, and an unreliable heading means the angle
    /// on screen is not worth a promise — a phone that buzzed "you are facing the Kaaba" off a
    /// magnetometer the system itself has asked the user to recalibrate would be asserting
    /// something it cannot know. Both fall back to *not aligned* rather than to a guess.
    private func updateAlignment() {
        let aligned: Bool

        if info == nil || !isHeadingReliable {
            aligned = false
        } else if isAlignedWithQibla {
            aligned = alignmentOffset <= Self.alignmentRelease
        } else {
            aligned = alignmentOffset <= Self.alignmentTolerance
        }

        // Guarded for the reason `isHeadingReliable` is: Observation invalidates on every write,
        // and this one is read by a view that must only react when the answer changes.
        if isAlignedWithQibla != aligned {
            isAlignedWithQibla = aligned
        }
    }

    // MARK: Lifecycle

    /// Finds the user, then follows the compass until cancelled.
    ///
    /// Structured on purpose: driven from the view's `.task`, so SwiftUI's teardown cancels it,
    /// the `for await` below ends, and the stream's termination handler stops the magnetometer.
    /// There is no stored `Task`, no `stop()`, and nothing left running behind a closed screen.
    func start() async {
        await resolvePosition()
        await observeHeading()
    }

    private func resolvePosition() async {
        defer { hasAttemptedPosition = true }

        if locationService.authorization == .notDetermined {
            await locationService.requestWhenInUseAuthorization()
        }

        guard locationService.authorization == .authorized,
              let coordinates = try? await locationService.currentCoordinates() else {
            // No fix. If onboarding seeded a position, or the user typed one, the bearing on
            // screen is still exact and nothing needs to change.
            return
        }

        apply(coordinates)
    }

    private func observeHeading() async {
        // Nothing to iterate on a Mac — `headingUpdates()` returns a finished stream — but
        // returning early keeps the intent legible rather than leaning on that.
        guard headingProvider.isHeadingAvailable else { return }

        for await heading in headingProvider.headingUpdates() {
            apply(heading)
        }
    }

    // MARK: Updates

    /// Internal rather than private so tests can feed headings deliberately instead of racing
    /// a live stream — the same reason `HomeViewModel.tick()` is reachable.
    func apply(_ heading: DeviceHeading) {
        deviceHeading = heading.trueHeading

        // Guarded because Observation invalidates on every write, equal or not: assigning the
        // same `true` fifty times a second would drag the whole readout into the needle's
        // redraw budget for nothing.
        if isHeadingReliable != heading.isReliable {
            isHeadingReliable = heading.isReliable
        }

        updateAlignment()
    }

    private func apply(_ coordinates: Coordinates) {
        info = getQiblaInfo.qiblaInfo(for: coordinates)

        // A new position moves the bearing under a needle that has not turned, so the answer to
        // "am I facing it?" can change without a single new heading arriving — typing a set of
        // coordinates on the other side of the world is the obvious case.
        updateAlignment()
    }

    // MARK: Manual location

    /// Whether what has been typed so far is a real point on the globe.
    var manualCoordinatesAreValid: Bool {
        parsedManualCoordinates != nil
    }

    private var parsedManualCoordinates: Coordinates? {
        guard let latitude = Double(manualLatitude.trimmingCharacters(in: .whitespaces)),
              let longitude = Double(manualLongitude.trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

        return Coordinates(latitude: latitude, longitude: longitude)
    }

    /// Accepts typed coordinates. Returns whether they were usable, so the view can keep the
    /// user on the field instead of silently doing nothing.
    @discardableResult
    func applyManualCoordinates() -> Bool {
        guard let coordinates = parsedManualCoordinates else { return false }

        apply(coordinates)
        return true
    }
}
