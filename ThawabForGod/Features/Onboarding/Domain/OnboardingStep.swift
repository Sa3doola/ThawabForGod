//
//  OnboardingStep.swift
//  ThawabForGod
//

import Foundation

/// The first-run flow, in order.
///
/// `done` is a real case rather than an absence: it is what the router watches for, and
/// having it in the enum keeps "finished" from being spelled differently in three places.
nonisolated enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome
    case location
    case notifications
    case method
    case done

    var id: Int { rawValue }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        // There is no going back past the first screen, and none out of the finished state —
        // once onboarding is done it is done.
        guard self != .done else { return nil }
        return OnboardingStep(rawValue: rawValue - 1)
    }

    /// Whether this step can be passed without answering it.
    ///
    /// Both permission screens can: the app is built to work without either grant, so
    /// insisting would be a lie about what it needs.
    var isSkippable: Bool {
        self == .location || self == .notifications
    }

    /// Steps the user actually sees, for progress display.
    static var visibleSteps: [OnboardingStep] {
        allCases.filter { $0 != .done }
    }
}
