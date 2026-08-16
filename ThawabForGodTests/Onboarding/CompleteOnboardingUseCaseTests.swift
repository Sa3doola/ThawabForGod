//
//  CompleteOnboardingUseCaseTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

struct CompleteOnboardingUseCaseTests {

    private func state(
        config: CalculationConfig = CalculationConfig(method: .karachi, madhab: .hanafi),
        coordinates: Coordinates? = Coordinates(latitude: 21.42, longitude: 39.82)
    ) -> OnboardingState {
        OnboardingState(step: .method, config: config, coordinates: coordinates)
    }

    @Test func itSeedsWhatWasAskedAndSetsTheFlag() {
        let repository = SpyOnboardingRepository()
        let useCase = CompleteOnboardingUseCase(repository: repository)

        useCase(state: state())

        let seed = repository.savedSeed
        #expect(seed?.config == CalculationConfig(method: .karachi, madhab: .hanafi))
        #expect(seed?.coordinates == Coordinates(latitude: 21.42, longitude: 39.82))
        #expect(repository.hasCompletedOnboarding)
    }

    @Test func itCompletesEvenWithNoLocation() {
        let repository = SpyOnboardingRepository()
        let useCase = CompleteOnboardingUseCase(repository: repository)

        useCase(state: state(coordinates: nil))

        #expect(repository.hasCompletedOnboarding)
        #expect(repository.savedSeed?.coordinates == nil)
    }
}

/// The real repository, against the same store Settings will read from later.
struct OnboardingRepositoryTests {

    private func makeRepository() -> (OnboardingRepository, InMemorySettingsStore) {
        let store = InMemorySettingsStore()
        return (OnboardingRepository(settingsStore: store), store)
    }

    private let seed = OnboardingSeed(
        config: CalculationConfig(method: .singapore, madhab: .hanafi),
        coordinates: Coordinates(latitude: 1.35, longitude: 103.82)
    )

    @Test func aFreshInstallHasNotOnboarded() {
        let (repository, _) = makeRepository()

        #expect(repository.hasCompletedOnboarding == false)
        #expect(repository.seededConfig == nil)
        #expect(repository.seededCoordinates == nil)
    }

    @Test func completingWritesValuesThatReadBack() {
        let (repository, _) = makeRepository()

        repository.completeOnboarding(with: seed)

        #expect(repository.hasCompletedOnboarding)
        #expect(repository.seededConfig == CalculationConfig(method: .singapore, madhab: .hanafi))
        #expect(repository.seededCoordinates == Coordinates(latitude: 1.35, longitude: 103.82))
    }

    /// The regression guard for a real bug: onboarding used to pin the language, digits,
    /// accent and appearance that happened to be in effect at first launch. Because a stored
    /// preference outranks the device, a user who later set this app to Arabic in iOS Settings
    /// kept seeing English, with no in-app Settings screen to undo it. Onboarding asks about
    /// none of these, so it must write none of them.
    @Test func onboardingDoesNotPinPreferencesTheUserWasNeverAsked() {
        let (repository, store) = makeRepository()

        repository.completeOnboarding(with: seed)

        #expect(store.string(for: .language) == nil)
        #expect(store.string(for: .numberSystem) == nil)
        #expect(store.string(for: .accentPalette) == nil)
        #expect(store.string(for: .appearance) == nil)
    }

    /// And with nothing pinned, the managers follow the device — which is what makes the iOS
    /// per-app language setting take effect at all.
    ///
    /// Main-actor isolated, alone in this suite: the repository is `nonisolated`, but the two
    /// managers it is checked against are UI types.
    @MainActor
    @Test func afterOnboardingTheManagersStillFollowTheDevice() {
        let (repository, store) = makeRepository()

        repository.completeOnboarding(with: seed)

        let localization = LocalizationManager(
            settingsStore: store,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
        let theme = ThemeManager(settingsStore: store)

        #expect(localization.language == AppLanguage.preferred)
        #expect(localization.numberSystem == NumberSystem.preferred(for: AppLanguage.preferred))
        #expect(theme.accent == AccentPalette.fallback)
        #expect(theme.appearance == AppearanceOverride.fallback)
    }

    @Test func skippingLocationLeavesNoCoordinatesBehind() {
        let (repository, _) = makeRepository()

        repository.completeOnboarding(
            with: OnboardingSeed(config: .default, coordinates: nil)
        )

        #expect(repository.hasCompletedOnboarding)
        #expect(repository.seededCoordinates == nil)
    }

    /// Zero is a real latitude, so an unset key and a stored `0.0` must not look alike.
    @Test func aZeroCoordinateIsStoredNotMistakenForUnset() {
        let (repository, _) = makeRepository()

        repository.completeOnboarding(
            with: OnboardingSeed(
                config: .default,
                coordinates: Coordinates(latitude: 0, longitude: 0)
            )
        )

        #expect(repository.seededCoordinates == Coordinates(latitude: 0, longitude: 0))
    }
}
