//
//  NamesTips.swift
//  ThawabForGod
//

import SwiftUI // `Text`; MEMBER_IMPORT_VISIBILITY means TipKit does not re-export it
import TipKit

/// The names grid's one piece of guidance, the signal its rule reads, and the seam the view model
/// reports it through. Feature-owned, exactly as `HomeTips` and `TasbihTips` are.

// MARK: - Signals

/// `nonisolated` because the module default is `MainActor` and rule evaluation is not: the event
/// is read from inside a `Tip`, which TipKit requires to be `Sendable`.
nonisolated enum NamesTipEvents {
    /// Donated once per appearance of the names grid.
    static let opened = Tips.Event(id: "names_opened")
}

// MARK: - Tips

/// Says that the cells go somewhere.
///
/// The grid reads as a poster rather than a menu — ninety-nine tiles of Arabic with no chevrons
/// and no disclosure — so that a cell is tappable at all is worth one sentence. It waits for a
/// second visit: on the first, a reader is still taking in the screen.
nonisolated struct NamesTapForMeaningTip: Tip {
    let titleText: String
    let messageText: String

    /// Fixed rather than derived from the type name, so renaming the type cannot silently
    /// re-show the tip to everyone who has already dismissed it.
    var id: String { "names_tap_for_meaning" }

    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }

    var rules: [Rule] {
        // The threshold is a literal because it has to be: `#Rule` compiles the closure into a
        // datastore query and rejects a named constant with "Event Rules require a count
        // comparison."
        #Rule(NamesTipEvents.opened) { $0.donations.count >= 2 }
    }
}

// MARK: - Reporting

/// How the grid feeds TipKit.
///
/// A protocol so the view model never imports TipKit and its tests never touch a real datastore —
/// donating from a test process would both need `Tips.configure` and leak state between runs.
nonisolated protocol NamesTipReporting: Sendable {
    /// Donates one appearance of the grid.
    func namesOpened() async

    /// The reader found it. Retires the tip rather than leaving it to expire.
    func nameOpened()
}

nonisolated struct NamesTipReporter: NamesTipReporting {
    func namesOpened() async {
        await NamesTipEvents.opened.donate()
    }

    func nameOpened() {
        // Built fresh with empty copy: `invalidate` matches on `id`, which is fixed above, so the
        // text this instance carries is irrelevant to retiring it.
        NamesTapForMeaningTip(titleText: "", messageText: "").invalidate(reason: .actionPerformed)
    }
}

/// Reports nothing. For previews, which have no configured TipKit datastore to donate into.
nonisolated struct NoNamesTipReporting: NamesTipReporting {
    func namesOpened() async {}
    func nameOpened() {}
}
