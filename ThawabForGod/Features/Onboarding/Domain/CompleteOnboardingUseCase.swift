//
//  CompleteOnboardingUseCase.swift
//  ThawabForGod
//

import Foundation

/// Turns what the first run gathered into persisted preferences.
///
/// Only what was actually asked. It is tempting to also pin the language, digits, accent and
/// appearance that happened to be in effect at first launch — they are right there on the UI
/// managers — but those are *computed* defaults, not answers, and persisting a default turns
/// it into a choice the user can no longer escape. See `OnboardingSeed`.
nonisolated struct CompleteOnboardingUseCase: Sendable {
    private let repository: any OnboardingRepositoring

    init(repository: any OnboardingRepositoring) {
        self.repository = repository
    }

    func callAsFunction(state: OnboardingState) {
        repository.completeOnboarding(
            with: OnboardingSeed(config: state.config, coordinates: state.coordinates)
        )
    }
}
