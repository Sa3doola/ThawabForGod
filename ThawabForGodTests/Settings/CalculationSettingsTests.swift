//
//  CalculationSettingsTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

@MainActor
struct CalculationSettingsTests {

    @Test func itStartsFromTheConfigItWasGiven() {
        let settings = CalculationSettings(
            config: CalculationConfig(method: .karachi, madhab: .hanafi),
            settingsStore: InMemorySettingsStore()
        )

        #expect(settings.config == CalculationConfig(method: .karachi, madhab: .hanafi))
    }

    /// The keys are the ones onboarding writes, not a second pair — so Settings edits the first
    /// run's answer rather than shadowing it with a copy nothing else reads.
    @Test func selectingAMethodWritesTheKeyOnboardingSeeds() {
        let store = InMemorySettingsStore()
        let settings = CalculationSettings(config: .default, settingsStore: store)

        settings.select(method: .egyptian)

        #expect(settings.config.method == .egyptian)
        #expect(store.string(for: .calculationMethod) == PrayerCalculationMethod.egyptian.rawValue)
    }

    /// Read back the way `OnboardingRepository` reads it, which is how the *next launch* will —
    /// this is the round trip that makes an edit here outlive the session.
    ///
    /// Both keys are written first because `seededConfig` is all-or-nothing: it answers `nil`
    /// unless the method and the madhab are both stored. Which is right — half a config is not a
    /// config — and it holds in production because onboarding always writes the pair.
    @Test func editsSurviveAsTheConfigTheNextLaunchReads() {
        let store = InMemorySettingsStore()
        let settings = CalculationSettings(config: .default, settingsStore: store)

        settings.select(method: .egyptian)
        settings.select(madhab: .hanafi)

        let restored = OnboardingRepository(settingsStore: store).seededConfig
        #expect(restored == CalculationConfig(method: .egyptian, madhab: .hanafi))
    }

    @Test func selectingAMadhabPersistsIt() {
        let store = InMemorySettingsStore()
        let settings = CalculationSettings(config: .default, settingsStore: store)

        settings.select(madhab: .hanafi)

        #expect(settings.config.madhab == .hanafi)
        #expect(store.string(for: .asrMadhab) == AsrMadhab.hanafi.rawValue)
    }

    /// Each choice is independent: changing one must not quietly reset the other.
    @Test func theTwoChoicesDoNotDisturbEachOther() {
        let settings = CalculationSettings(
            config: CalculationConfig(method: .ummAlQura, madhab: .hanafi),
            settingsStore: InMemorySettingsStore()
        )

        settings.select(method: .turkey)

        #expect(settings.config == CalculationConfig(method: .turkey, madhab: .hanafi))
    }
}
