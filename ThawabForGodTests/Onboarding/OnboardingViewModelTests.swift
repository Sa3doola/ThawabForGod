//
//  OnboardingViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct OnboardingViewModelTests {

    private struct Harness {
        let viewModel: OnboardingViewModel
        let location: MockLocationService
        let notifications: MockNotificationService
        let repository: SpyOnboardingRepository
        let settingsStore: InMemorySettingsStore
        let tips: SpyOnboardingTipReporter
    }

    private func makeHarness(
        locationOutcome: LocationAuthorization = .authorized,
        coordinatesResult: Result<Coordinates, Error> = .success(Coordinates(latitude: 51.5, longitude: -0.12)),
        notificationOutcome: NotificationAuthorization = .authorized,
        locale: Locale = Locale(identifier: "en_US")
    ) -> Harness {
        let location = MockLocationService(
            outcomeOfPrompt: locationOutcome,
            coordinatesResult: coordinatesResult
        )
        let notifications = MockNotificationService(outcomeOfPrompt: notificationOutcome)
        let repository = SpyOnboardingRepository()
        let settingsStore = InMemorySettingsStore()
        let tips = SpyOnboardingTipReporter()

        let viewModel = OnboardingViewModel(
            locationService: location,
            notificationService: notifications,
            completeOnboarding: CompleteOnboardingUseCase(repository: repository),
            tips: tips,
            locale: locale
        )

        return Harness(
            viewModel: viewModel,
            location: location,
            notifications: notifications,
            repository: repository,
            settingsStore: settingsStore,
            tips: tips
        )
    }

    // MARK: Step machine

    @Test func itStartsAtWelcome() {
        let harness = makeHarness()

        #expect(harness.viewModel.step == .welcome)
        #expect(harness.viewModel.canGoBack == false)
    }

    @Test func advancingWalksTheStepsInOrder() {
        let viewModel = makeHarness().viewModel

        viewModel.advance()
        #expect(viewModel.step == .location)

        viewModel.advance()
        #expect(viewModel.step == .notifications)

        viewModel.advance()
        #expect(viewModel.step == .method)
    }

    @Test func advancingPastTheLastStepFinishes() {
        let harness = makeHarness()

        for _ in OnboardingStep.visibleSteps {
            harness.viewModel.advance()
        }

        #expect(harness.viewModel.step == .done)
        #expect(harness.viewModel.isFinished)
    }

    @Test func goingBackReturnsToThePreviousStep() {
        let viewModel = makeHarness().viewModel

        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.step == .notifications)

        viewModel.back()
        #expect(viewModel.step == .location)
    }

    @Test func thereIsNoGoingBackFromTheFirstStep() {
        let viewModel = makeHarness().viewModel

        viewModel.back()

        #expect(viewModel.step == .welcome)
    }

    @Test func onlyThePermissionStepsCanBeSkipped() {
        #expect(OnboardingStep.welcome.isSkippable == false)
        #expect(OnboardingStep.location.isSkippable)
        #expect(OnboardingStep.notifications.isSkippable)
        #expect(OnboardingStep.method.isSkippable == false)
    }

    @Test func skippingAPermissionStepRecordsItAndMovesOn() {
        let viewModel = makeHarness().viewModel

        viewModel.advance() // location
        viewModel.skip()

        #expect(viewModel.state.location == .skipped)
        #expect(viewModel.step == .notifications)
    }

    @Test func skippingANonSkippableStepDoesNothing() {
        let viewModel = makeHarness().viewModel

        viewModel.skip()

        #expect(viewModel.step == .welcome)
    }

    // MARK: Permissions

    @Test func grantingLocationRecordsItAndReadsAPosition() async {
        let harness = makeHarness()

        await harness.viewModel.requestLocationPermission()

        #expect(harness.viewModel.state.location == .granted)
        #expect(harness.viewModel.state.coordinates == Coordinates(latitude: 51.5, longitude: -0.12))
        #expect(harness.location.authorizationRequestCount == 1)
    }

    @Test func refusingLocationIsRecordedAndNoPositionIsRead() async {
        let harness = makeHarness(locationOutcome: .denied)

        await harness.viewModel.requestLocationPermission()

        #expect(harness.viewModel.state.location == .denied)
        #expect(harness.viewModel.state.hasLocation == false)
        #expect(harness.location.coordinatesRequestCount == 0)
    }

    /// Permission granted but the fix failed. That is still a grant, and the manual fallback
    /// has to remain available rather than the flow dead-ending.
    @Test func aGrantWithNoFixStillCountsAsGranted() async {
        let harness = makeHarness(coordinatesResult: .failure(LocationError.unavailable("no fix")))

        await harness.viewModel.requestLocationPermission()

        #expect(harness.viewModel.state.location == .granted)
        #expect(harness.viewModel.state.hasLocation == false)
    }

    @Test func grantingNotificationsIsRecorded() async {
        let harness = makeHarness()

        await harness.viewModel.requestNotificationPermission()

        #expect(harness.viewModel.state.notifications == .granted)
    }

    @Test func refusingNotificationsIsRecorded() async {
        let harness = makeHarness(notificationOutcome: .denied)

        await harness.viewModel.requestNotificationPermission()

        #expect(harness.viewModel.state.notifications == .denied)
    }

    // MARK: Manual coordinates

    @Test func validManualCoordinatesAreAccepted() {
        let viewModel = makeHarness().viewModel

        viewModel.manualLatitude = "21.42"
        viewModel.manualLongitude = "39.82"

        #expect(viewModel.manualCoordinatesAreValid)
        #expect(viewModel.applyManualCoordinates())
        #expect(viewModel.state.coordinates == Coordinates(latitude: 21.42, longitude: 39.82))
    }

    @Test func manualCoordinatesTolerateSurroundingWhitespace() {
        let viewModel = makeHarness().viewModel

        viewModel.manualLatitude = "  21.42 "
        viewModel.manualLongitude = " 39.82  "

        #expect(viewModel.applyManualCoordinates())
    }

    @Test(arguments: [
        ("91", "0"),      // latitude past the pole
        ("0", "181"),     // longitude past the meridian
        ("abc", "0"),     // not a number
        ("", "39.82"),    // half-finished
        ("-90.1", "0")
    ])
    func outOfRangeOrUnparseableCoordinatesAreRejected(latitude: String, longitude: String) {
        let viewModel = makeHarness().viewModel

        viewModel.manualLatitude = latitude
        viewModel.manualLongitude = longitude

        #expect(viewModel.manualCoordinatesAreValid == false)
        #expect(viewModel.applyManualCoordinates() == false)
        #expect(viewModel.state.hasLocation == false)
    }

    @Test func theExtremesOfTheGlobeAreValid() {
        let viewModel = makeHarness().viewModel

        viewModel.manualLatitude = "-90"
        viewModel.manualLongitude = "180"

        #expect(viewModel.manualCoordinatesAreValid)
    }

    // MARK: Configuration

    @Test func theMethodIsPreselectedFromTheRegion() {
        #expect(makeHarness(locale: Locale(identifier: "ar_SA")).viewModel.state.config.method == .ummAlQura)
        #expect(makeHarness(locale: Locale(identifier: "en_US")).viewModel.state.config.method == .northAmerica)
        #expect(makeHarness(locale: Locale(identifier: "tr_TR")).viewModel.state.config.method == .turkey)
        // Somewhere with no dedicated authority falls back to the global default.
        #expect(makeHarness(locale: Locale(identifier: "fr_FR")).viewModel.state.config.method == .muslimWorldLeague)
    }

    @Test func selectingAMethodAndMadhabUpdatesTheConfig() {
        let viewModel = makeHarness().viewModel

        viewModel.select(method: .karachi)
        viewModel.select(madhab: .hanafi)

        #expect(viewModel.state.config == CalculationConfig(method: .karachi, madhab: .hanafi))
    }

    // MARK: Finishing

    @Test func finishingPersistsTheAssembledConfiguration() async throws {
        let harness = makeHarness()

        await harness.viewModel.requestLocationPermission()
        harness.viewModel.select(method: .karachi)
        harness.viewModel.select(madhab: .hanafi)

        for _ in OnboardingStep.visibleSteps {
            harness.viewModel.advance()
        }

        let seed = try #require(harness.repository.savedSeed)
        #expect(seed.config == CalculationConfig(method: .karachi, madhab: .hanafi))
        #expect(seed.coordinates == Coordinates(latitude: 51.5, longitude: -0.12))
        #expect(harness.repository.hasCompletedOnboarding)
    }

    /// The path where the user refuses everything still has to reach the end — nothing in
    /// this flow may be load-bearing.
    @Test func skippingEverythingStillCompletesOnboarding() {
        let harness = makeHarness()

        harness.viewModel.advance() // location
        harness.viewModel.skip()
        harness.viewModel.skip()    // notifications
        harness.viewModel.advance() // finishes from the method step

        #expect(harness.viewModel.isFinished)
        #expect(harness.repository.hasCompletedOnboarding)
        #expect(harness.repository.savedSeed?.coordinates == nil)
    }

    /// Finishing records the answers and nothing more. The language and theme in effect at
    /// first launch are device defaults, not answers, and pinning them is what used to leave a
    /// user stuck in a language they never picked — see `OnboardingSeed`.
    @Test func finishingSeedsOnlyWhatWasAsked() {
        let harness = makeHarness()

        for _ in OnboardingStep.visibleSteps {
            harness.viewModel.advance()
        }

        let seed = harness.repository.savedSeed
        #expect(seed == OnboardingSeed(config: harness.viewModel.state.config, coordinates: nil))
    }

    /// The donation gating the post-onboarding tip. It can only be made here, so it has to
    /// survive every route to the end — including the one where the user skips everything.
    @Test func finishingDonatesTheCompletionEvent() {
        let harness = makeHarness()

        harness.viewModel.advance() // location
        harness.viewModel.skip()
        harness.viewModel.skip()    // notifications
        harness.viewModel.advance() // finishes from the method step

        #expect(harness.tips.completions == 1)
    }

    @Test func anUnfinishedOnboardingDonatesNothing() {
        let harness = makeHarness()

        harness.viewModel.advance()

        #expect(harness.tips.completions == 0)
    }
}
