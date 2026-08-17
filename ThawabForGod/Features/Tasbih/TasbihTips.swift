//
//  TasbihTips.swift
//  ThawabForGod
//

import SwiftUI // `Text`; MEMBER_IMPORT_VISIBILITY means TipKit does not re-export it
import TipKit

/// The counter's one piece of guidance, the signals its rule reads, and the seam the view model
/// reports them through. Feature-owned, exactly as `HomeTips` is.

// MARK: - Signals

/// `nonisolated` because the module default is `MainActor` and rule evaluation is not: the event
/// is read from inside a `Tip`, which TipKit requires to be `Sendable`.
nonisolated enum TasbihTipEvents {
    /// Donated once per recitation counted.
    static let counted = Tips.Event(id: "tasbih_counted")
}

// MARK: - Tips

/// Teaches the one gesture on the counter that nothing on screen advertises.
///
/// A reset button beside the count would be a button someone eventually hits at 98 of 100, so the
/// gesture is a long press instead — which makes it invisible, which is what a tip is for. It
/// waits until the user has actually counted something: told before there is anything to lose,
/// "hold to reset" is a solution to a problem they have not had yet.
nonisolated struct TasbihResetTip: Tip {
    let titleText: String
    let messageText: String

    /// Fixed rather than derived from the type name, so renaming the type cannot silently
    /// re-show the tip to everyone who has already dismissed it.
    var id: String { "tasbih_hold_to_reset" }

    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }

    var rules: [Rule] {
        // The threshold is a literal because it has to be: `#Rule` compiles the closure into a
        // datastore query and rejects a named constant with "Event Rules require a count
        // comparison."
        #Rule(TasbihTipEvents.counted) { $0.donations.count >= 10 }
    }
}

// MARK: - Reporting

/// How the counter feeds TipKit.
///
/// A protocol so the view model never imports TipKit and its tests never touch a real datastore —
/// donating from a test process would both need `Tips.configure` and leak state between runs.
nonisolated protocol TasbihTipReporting: Sendable {
    /// Records one recitation. Called on every tap, so it must not block one.
    func counted()

    /// The user found the gesture. Retires the tip rather than leaving it to expire.
    func resetPerformed()
}

/// Reports nothing. For previews, which have no configured TipKit datastore to donate into.
nonisolated struct NoTasbihTipReporting: TasbihTipReporting {
    func counted() {}
    func resetPerformed() {}
}

nonisolated struct TasbihTipReporter: TasbihTipReporting {

    /// Donation is `async` and a tap is not, so it is handed to a task rather than awaited.
    /// Unstructured is right here: a tip donation is fire-and-forget by nature, and tying it to
    /// the view's lifetime would drop the donation from the tap that dismissed the screen.
    func counted() {
        Task { await TasbihTipEvents.counted.donate() }
    }

    func resetPerformed() {
        // Built fresh with empty copy: `invalidate` matches on `id`, which is fixed above, so the
        // text this instance carries is irrelevant to retiring it.
        TasbihResetTip(titleText: "", messageText: "").invalidate(reason: .actionPerformed)
    }
}
