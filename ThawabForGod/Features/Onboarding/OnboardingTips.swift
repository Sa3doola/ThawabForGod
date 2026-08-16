//
//  OnboardingTips.swift
//  ThawabForGod
//

import SwiftUI // `Text`; MEMBER_IMPORT_VISIBILITY means TipKit does not re-export it
import TipKit

/// The one thing worth saying after the first run: the calculation choices are not permanent.
///
/// **This tip is defined but not yet attached to a view, and that is deliberate.** Its message
/// points at Settings, which has not shipped — displaying it now would send the user looking
/// for a screen that does not exist. The *donation* below cannot wait, though: it can only be
/// made at the moment onboarding finishes, so a user who onboards today still has it recorded
/// when Settings arrives. Attaching the tip is then one `.popoverTip(_:)` on the calculation
/// method row.

// MARK: - Signals

nonisolated enum OnboardingTipEvents {
    /// Donated once, when the last onboarding step is accepted.
    static let completed = Tips.Event(id: "onboarding_completed")
}

// MARK: - Tips

/// Copy is injected already resolved — see `HomeTomorrowsPrayerTip` for why a `Sendable` tip
/// cannot reach `LocalizationManager` itself.
nonisolated struct OnboardingCalculationMethodTip: Tip {
    let titleText: String
    let messageText: String

    var id: String { "onboarding_calculation_method" }

    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }

    var rules: [Rule] {
        // Post-onboarding only. Someone still inside the flow is looking at the method picker
        // already and does not need to be told where it lives.
        #Rule(OnboardingTipEvents.completed) { $0.donations.count >= 1 }
    }
}

// MARK: - Reporting

/// How onboarding feeds TipKit. Injected, so `OnboardingViewModel` neither imports TipKit nor
/// writes to a real datastore under test.
nonisolated protocol OnboardingTipReporting: Sendable {
    func onboardingCompleted()
}

nonisolated struct OnboardingTipReporter: OnboardingTipReporting {
    /// Synchronous by design, though `donate()` is not.
    ///
    /// The step machine that calls this is synchronous, and making it `async` would push a
    /// suspension point into `advance()` for no benefit. The donation is fire-and-forget:
    /// losing it to an app kill in the milliseconds before it lands costs one tip, and the
    /// alternative — holding up the transition off the last onboarding screen — is worse.
    func onboardingCompleted() {
        Task {
            await OnboardingTipEvents.completed.donate()
        }
    }
}
