//
//  QiblaViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct QiblaViewModelTests {

    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)

    /// The doubles are built inside rather than defaulted in the signature: default arguments
    /// are evaluated in a nonisolated context, and both of these are `@MainActor` types.
    private func makeViewModel(
        bearing: Double = 118.987,
        coordinates: Coordinates? = nil,
        location: MockLocationService? = nil,
        heading: StubHeadingProvider? = nil
    ) -> (QiblaViewModel, StubHeadingProvider) {
        let location = location ?? MockLocationService(authorization: .authorized)
        let heading = heading ?? StubHeadingProvider()

        let viewModel = QiblaViewModel(
            getQiblaInfo: GreatCircleQiblaInfoUseCase(engine: StubQiblaEngine(bearing: bearing)),
            locationService: location,
            headingProvider: heading,
            coordinates: coordinates
        )

        return (viewModel, heading)
    }

    /// Drives `start()` the way the view's `.task` does: spawned, run until the state under
    /// test has settled, then cancelled.
    ///
    /// Awaiting `start()` directly would hang wherever a compass is available — the heading
    /// loop inside it is meant to run until the screen goes away, and that is exactly the
    /// behaviour being relied on here.
    private func runStart(
        _ viewModel: QiblaViewModel,
        _ heading: StubHeadingProvider,
        until isSettled: () -> Bool
    ) async {
        let task = Task { await viewModel.start() }

        while !isSettled() {
            await Task.yield()
        }

        task.cancel()
        heading.finish()
        await task.value
    }

    // MARK: Needle maths

    @Test func theNeedleIsTheBearingMinusTheHeading() {
        let (viewModel, _) = makeViewModel(bearing: 100, coordinates: london)

        viewModel.apply(.stub(30))

        #expect(viewModel.needleRotation == 70)
    }

    /// The case a plain subtraction gets wrong: a device facing almost due north, with the
    /// Kaaba just east of it, must give a small positive rotation and not -340.
    @Test func aNegativeDifferenceWrapsIntoAFullTurn() {
        let (viewModel, _) = makeViewModel(bearing: 10, coordinates: london)

        viewModel.apply(.stub(350))

        #expect(viewModel.needleRotation == 20)
    }

    @Test func facingTheQiblaLeavesTheNeedleStraightAhead() {
        let (viewModel, _) = makeViewModel(bearing: 118.987, coordinates: london)

        viewModel.apply(.stub(118.987))

        #expect(viewModel.needleRotation == 0)
    }

    @Test(arguments: [
        (0.0, 0.0),
        (359.0, 359.0),
        (360.0, 0.0),
        (-1.0, 359.0),
        (-360.0, 0.0),
        (450.0, 90.0),
        (-450.0, 270.0)
    ])
    func normalisationFoldsAnyAngleIntoATurn(input: Double, expected: Double) {
        #expect(QiblaViewModel.normalized(input) == expected)
    }

    // MARK: Position

    @Test func aSeededPositionGivesABearingBeforeAnythingHasStarted() {
        let (viewModel, _) = makeViewModel(bearing: 118.987, coordinates: london)

        #expect(viewModel.coordinates == london)
        #expect(viewModel.qiblaDirection == 118.987)
        #expect(viewModel.status == .ready)
    }

    @Test func withNoPositionAndNothingAttemptedYetTheScreenIsLocating() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.status == .locating)
    }

    @Test(.timeLimit(.minutes(1)))
    func startingReadsAPositionAndResolvesTheQibla() async {
        let location = MockLocationService(
            authorization: .authorized,
            coordinatesResult: .success(london)
        )
        let (viewModel, heading) = makeViewModel(bearing: 42, location: location)

        await runStart(viewModel, heading) { viewModel.coordinates != nil }

        #expect(viewModel.coordinates == london)
        #expect(viewModel.qiblaDirection == 42)
    }

    // MARK: Refusal

    /// Denied *and* nothing seeded: there is no bearing to show, so the screen offers the
    /// manual-entry way out rather than a needle pointing at nothing.
    @Test(.timeLimit(.minutes(1)))
    func aRefusedPermissionWithNoSeedAsksForCoordinates() async {
        let location = MockLocationService(authorization: .denied, outcomeOfPrompt: .denied)
        let (viewModel, heading) = makeViewModel(location: location)

        await runStart(viewModel, heading) { viewModel.hasAttemptedPosition }

        #expect(viewModel.status == .permissionDenied)
        #expect(viewModel.coordinates == nil)
    }

    /// A refusal is not a dead end when onboarding already captured a position: the bearing is
    /// exact, so nothing is asked of the user.
    @Test(.timeLimit(.minutes(1)))
    func aRefusedPermissionKeepsASeededPosition() async {
        let location = MockLocationService(authorization: .denied, outcomeOfPrompt: .denied)
        let (viewModel, heading) = makeViewModel(coordinates: london, location: location)

        await runStart(viewModel, heading) { viewModel.hasAttemptedPosition }

        #expect(viewModel.coordinates == london)
        #expect(viewModel.status == .ready)
    }

    @Test(.timeLimit(.minutes(1)))
    func typedCoordinatesRecoverFromARefusal() async {
        let location = MockLocationService(authorization: .denied, outcomeOfPrompt: .denied)
        let (viewModel, heading) = makeViewModel(bearing: 118.987, location: location)

        await runStart(viewModel, heading) { viewModel.hasAttemptedPosition }
        #expect(viewModel.status == .permissionDenied)

        viewModel.manualLatitude = "51.5074"
        viewModel.manualLongitude = "-0.1278"

        #expect(viewModel.manualCoordinatesAreValid)
        #expect(viewModel.applyManualCoordinates())
        #expect(viewModel.coordinates == london)
        #expect(viewModel.status == .ready)
    }

    @Test func anImpossibleLatitudeIsRejected() {
        let (viewModel, _) = makeViewModel()

        viewModel.manualLatitude = "91"
        viewModel.manualLongitude = "0"

        #expect(viewModel.manualCoordinatesAreValid == false)
        #expect(viewModel.applyManualCoordinates() == false)
        #expect(viewModel.coordinates == nil)
    }

    // MARK: Alignment

    /// The offset is measured the short way round the dial, which is the only reading a
    /// tolerance can be compared against: a needle at 359° is one degree off, not 359.
    @Test(arguments: [
        (100.0, 100.0, 0.0),
        (100.0, 96.0, 4.0),
        (100.0, 104.0, 4.0),
        (1.0, 359.0, 2.0),
        (359.0, 1.0, 2.0),
        (0.0, 180.0, 180.0)
    ])
    func theOffsetIsTheShorterArcToStraightAhead(
        bearing: Double,
        heading: Double,
        expected: Double
    ) {
        let (viewModel, _) = makeViewModel(bearing: bearing, coordinates: london)

        viewModel.apply(.stub(heading))

        #expect(abs(viewModel.alignmentOffset - expected) < 0.000_1)
    }

    @Test func pointingAtTheKaabaAligns() {
        let (viewModel, _) = makeViewModel(bearing: 100, coordinates: london)

        viewModel.apply(.stub(0))
        #expect(viewModel.isAlignedWithQibla == false)

        viewModel.apply(.stub(98))
        #expect(viewModel.isAlignedWithQibla)
    }

    /// The whole reason there are two thresholds. A hand held at the edge of the tolerance
    /// wanders across it several times a second, and on a single boundary every crossing is a
    /// ring appearing and a haptic firing.
    @Test func alignmentHoldsThroughTheGapBetweenTheTwoThresholds() {
        let (viewModel, _) = makeViewModel(bearing: 100, coordinates: london)

        // Inside the tolerance: it takes.
        viewModel.apply(.stub(97))
        #expect(viewModel.isAlignedWithQibla)

        // Past the tolerance but inside the release: it stays, which a single threshold would
        // not have done.
        viewModel.apply(.stub(107))
        #expect(viewModel.isAlignedWithQibla)

        // Past the release: it lets go.
        viewModel.apply(.stub(110))
        #expect(viewModel.isAlignedWithQibla == false)

        // And getting it back needs the tolerance again, not the release.
        viewModel.apply(.stub(107))
        #expect(viewModel.isAlignedWithQibla == false)
    }

    /// A reading the system itself has asked the user to recalibrate cannot support the claim
    /// the ring and the haptic make, so it is never aligned — however close the angle looks.
    @Test func anUnreliableHeadingIsNeverAligned() {
        let (viewModel, _) = makeViewModel(bearing: 100, coordinates: london)

        viewModel.apply(.stub(100, accuracy: DeviceHeading.calibrationThreshold + 5))

        #expect(viewModel.status == .needsCalibration)
        #expect(viewModel.alignmentOffset == 0)
        #expect(viewModel.isAlignedWithQibla == false)
    }

    /// An alignment that dropped when the compass wobbled comes back on the next good reading
    /// rather than waiting for the user to turn away and back.
    @Test func alignmentReturnsWhenTheHeadingBecomesReliableAgain() {
        let (viewModel, _) = makeViewModel(bearing: 100, coordinates: london)

        viewModel.apply(.stub(100))
        #expect(viewModel.isAlignedWithQibla)

        viewModel.apply(.stub(100, accuracy: DeviceHeading.calibrationThreshold + 5))
        #expect(viewModel.isAlignedWithQibla == false)

        viewModel.apply(.stub(100))
        #expect(viewModel.isAlignedWithQibla)
    }

    /// With no position there is no bearing to be aligned with, and `qiblaDirection` falls back
    /// to zero — so a device facing north would otherwise buzz at nothing.
    @Test func withNoPositionNothingIsAligned() {
        let (viewModel, _) = makeViewModel(bearing: 100)

        viewModel.apply(.stub(0))

        #expect(viewModel.isAlignedWithQibla == false)
    }

    /// A position can arrive after the heading has: the compass was already pointing the right
    /// way, and typing coordinates is what makes that mean something. Nothing new comes off the
    /// magnetometer, so the answer has to be recomputed where the position lands.
    @Test func aPositionTypedInResolvesAlignmentWithNoNewHeading() {
        let (viewModel, _) = makeViewModel(bearing: 100)

        viewModel.apply(.stub(100))
        #expect(viewModel.isAlignedWithQibla == false)

        viewModel.manualLatitude = "51.5074"
        viewModel.manualLongitude = "-0.1278"
        #expect(viewModel.applyManualCoordinates())

        #expect(viewModel.isAlignedWithQibla)
    }

    // MARK: No magnetometer

    /// A Mac, or an iPad without a compass. The screen must land on the static readout, which
    /// is a first-class state and not a failure — the bearing it shows is exact.
    @Test(.timeLimit(.minutes(1)))
    func aDeviceWithoutACompassGetsTheStaticReadout() async {
        let heading = StubHeadingProvider(isHeadingAvailable: false)
        let (viewModel, _) = makeViewModel(coordinates: london, heading: heading)

        await viewModel.start()

        #expect(viewModel.status == .headingUnavailable)
        #expect(viewModel.status.showsLiveCompass == false)
        #expect(viewModel.status.showsReadout)
        #expect(viewModel.qiblaDirection == 118.987)
        // Nothing was subscribed to, so no magnetometer was ever asked for.
        #expect(heading.subscriptionCount == 0)
    }

    /// `start()` must return rather than hang when there is no compass — the `.task` that drives
    /// it has to be able to finish.
    @Test(.timeLimit(.minutes(1)))
    func startingReturnsImmediatelyWithoutACompass() async {
        let heading = StubHeadingProvider(isHeadingAvailable: false)
        let (viewModel, _) = makeViewModel(coordinates: london, heading: heading)

        await viewModel.start()

        #expect(viewModel.deviceHeading == 0)
    }

    // MARK: Calibration

    @Test func aPoorReadingAsksForCalibration() {
        let (viewModel, _) = makeViewModel(coordinates: london)

        viewModel.apply(.stub(30, accuracy: 45))

        #expect(viewModel.status == .needsCalibration)
        // Still a live compass — the needle stays on screen, with the hint above it.
        #expect(viewModel.status.showsLiveCompass)
    }

    /// CoreLocation reports a negative accuracy for a reading it cannot vouch for at all.
    @Test func anInvalidAccuracyAlsoAsksForCalibration() {
        let (viewModel, _) = makeViewModel(coordinates: london)

        viewModel.apply(.stub(30, accuracy: -1))

        #expect(viewModel.status == .needsCalibration)
    }

    @Test func aGoodReadingClearsTheCalibrationHint() {
        let (viewModel, _) = makeViewModel(coordinates: london)

        viewModel.apply(.stub(30, accuracy: 45))
        viewModel.apply(.stub(31, accuracy: 5))

        #expect(viewModel.status == .ready)
    }

    // MARK: The live feed

    /// End to end through the real `AsyncStream`, rather than the direct `apply(_:)` the maths
    /// tests use — this is the check that the loop in `start()` is actually consuming.
    @Test(.timeLimit(.minutes(1)))
    func headingsFromTheStreamTurnTheNeedle() async {
        let (viewModel, heading) = makeViewModel(bearing: 100, coordinates: london)

        let task = Task { await viewModel.start() }
        while heading.subscriptionCount == 0 {
            await Task.yield()
        }

        heading.send(.stub(30))
        while viewModel.deviceHeading != 30 {
            await Task.yield()
        }

        #expect(viewModel.needleRotation == 70)

        task.cancel()
        heading.finish()
        await task.value
    }

    /// Cancelling the driving task must end the stream, which is what stops the magnetometer in
    /// production — there is no `stop()` for the view to call.
    @Test(.timeLimit(.minutes(1)))
    func cancellingTheTaskEndsTheFeed() async {
        let (viewModel, heading) = makeViewModel(coordinates: london)

        let task = Task { await viewModel.start() }
        while heading.subscriptionCount == 0 {
            await Task.yield()
        }

        task.cancel()
        await task.value

        while !heading.isFinished {
            await Task.yield()
        }
        #expect(heading.isFinished)
    }
}
