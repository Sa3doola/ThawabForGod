//
//  HomeTips.swift
//  ThawabForGod
//

import SwiftUI // `Text`; MEMBER_IMPORT_VISIBILITY means TipKit does not re-export it
import TipKit

/// Home's contextual guidance: the tip itself, the signals its rules read, and the seam the
/// view model reports those signals through.
///
/// Feature-owned on purpose. `Core/Tips` configures the datastore and knows nothing about what
/// any screen wants to say; the content and the eligibility rules live next to the screen they
/// belong to.

// MARK: - Signals

/// The events Home donates. A namespace rather than a member of the tip, because an event is
/// an input that several tips may eventually share.
///
/// `nonisolated` because the module default is `MainActor` and rule evaluation is not: the
/// event is read from inside a `Tip`, which TipKit requires to be `Sendable`.
nonisolated enum HomeTipEvents {
    /// Donated once per appearance of the Home screen.
    static let opened = Tips.Event(id: "home_opened")
}

// MARK: - Tips

/// Explains the one moment Home's headline looks wrong.
///
/// After Isha the countdown retargets *tomorrow's* Fajr, so the card names a prayer whose row
/// is sitting greyed-out at the top of today's list. That is correct and it is confusing, which
/// is exactly what a tip is for.
///
/// The copy is injected already resolved rather than looked up here: strings come from
/// `LocalizationManager`, which is `@MainActor` observable state a `Sendable` tip cannot reach.
/// Passing them in also means the tip follows a language change like every other string on the
/// screen. Identity is the fixed `id` below, not the instance, so rebuilding the value on each
/// redraw never resurrects a dismissed tip.
nonisolated struct HomeTomorrowsPrayerTip: Tip {
    let titleText: String
    let messageText: String

    /// Fixed rather than derived from the type name, so renaming the type cannot silently
    /// re-show the tip to everyone who has already dismissed it.
    var id: String { "home_tomorrows_prayer" }

    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }

    /// Whether the headline is currently counting down to tomorrow's Fajr.
    ///
    /// Written by `HomeViewModel` through `HomeTipReporting`. A parameter and not a use case:
    /// tips read flags, they never reach into Domain.
    @Parameter static var isCountingDownToTomorrow: Bool = false

    var rules: [Rule] {
        // Not on first launch. Someone still finding their way around the app does not need a
        // footnote about an edge case; by the third visit the screen is familiar enough that
        // the odd-looking headline is worth explaining.
        //
        // The threshold is a literal because it has to be: `#Rule` compiles the closure into a
        // datastore query and rejects a named constant with "Event Rules require a count
        // comparison."
        #Rule(HomeTipEvents.opened) { $0.donations.count >= 3 }

        // And only while the headline actually shows tomorrow's Fajr — the tip appears at the
        // moment it explains something, not hours before.
        #Rule(Self.$isCountingDownToTomorrow) { $0 }
    }
}

/// Explains where the Hijri date on the header comes from.
///
/// Reachable, unlike the tip above — which is the point of it existing. The rollover tip is
/// gated on a state that only occurs between Isha and Fajr, so a user who opens the app during
/// the day never sees TipKit do anything at all. This one needs only that Home has been opened
/// a few times, and it says something worth knowing: the date is Umm al-Qura, a calculated
/// calendar, and a local sighting can put the real date a day either side of it.
nonisolated struct HomeHijriDateTip: Tip {
    let titleText: String
    let messageText: String

    var id: String { "home_hijri_date" }

    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }

    var rules: [Rule] {
        #Rule(HomeTipEvents.opened) { $0.donations.count >= 3 }
    }
}

// MARK: - Reporting

/// How Home feeds TipKit.
///
/// A protocol so the view model never imports TipKit and its tests never touch a real
/// datastore — donating from a test process would both need `Tips.configure` and leak state
/// between runs.
nonisolated protocol HomeTipReporting: Sendable {
    /// Donates one appearance of the Home screen.
    func homeOpened() async

    /// Records whether the headline is counting down to tomorrow's Fajr.
    func countingDownToTomorrow(_ isCountingDown: Bool)
}

nonisolated struct HomeTipReporter: HomeTipReporting {
    func homeOpened() async {
        await HomeTipEvents.opened.donate()
    }

    func countingDownToTomorrow(_ isCountingDown: Bool) {
        HomeTomorrowsPrayerTip.isCountingDownToTomorrow = isCountingDown
    }
}
