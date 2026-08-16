//
//  OnboardingState.swift
//  ThawabForGod
//

import Foundation

/// How a permission request ended.
///
/// `skipped` is kept apart from `denied` on purpose: a user who stepped past the screen has
/// not refused anything, and a later prompt from Settings is fair. One who said no has.
nonisolated enum PermissionOutcome: Sendable, Equatable {
    case notRequested
    case granted
    case denied
    case skipped
}

/// Everything the first run has gathered so far.
///
/// A plain value: the view model owns one and replaces it as the user moves, which makes the
/// step machine trivial to assert against in a test.
nonisolated struct OnboardingState: Equatable, Sendable {
    var step: OnboardingStep = .welcome
    var config: CalculationConfig = .default
    var location: PermissionOutcome = .notRequested
    var notifications: PermissionOutcome = .notRequested

    /// Where the user is, once it is known — from the device if permission was granted, or
    /// typed in by hand if it was not.
    var coordinates: Coordinates?

    /// Whether the app has a usable position by any route.
    var hasLocation: Bool { coordinates != nil }
}

/// What onboarding hands to the rest of the app when it finishes.
/// What the first run actually asked the user, and nothing else.
///
/// Language, digits, accent and appearance are deliberately absent. Onboarding never asks
/// about them, so writing them would record a preference the user never expressed — and a
/// recorded preference outranks the system for good. That is what made a user who set this app
/// to Arabic in iOS Settings keep seeing English: the language they never chose had been
/// pinned at first launch and there is no Settings screen yet to unpin it. Leaving these unset
/// lets `LocalizationManager` and `ThemeManager` fall back to the device each launch, which is
/// what a user who has expressed nothing should get.
nonisolated struct OnboardingSeed: Equatable, Sendable {
    let config: CalculationConfig
    let coordinates: Coordinates?
}
