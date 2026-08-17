//
//  ResetTipsUseCase.swift
//  ThawabForGod
//

import Foundation

/// Brings back the tips the user has dismissed.
///
/// One line of delegation, and worth a type for two reasons. It keeps `SettingsViewModel`
/// depending on the feature's own vocabulary rather than on a service whose protocol speaks
/// TipKit's — and it gives the caveat below a single place to be recorded.
///
/// **The reset does not take effect until the next launch.** TipKit reads the datastore when
/// `Tips.configure` runs, so wiping it mid-session changes nothing on screen; see the note on
/// `TipsService.resetAll()`. Settings therefore has to say so, which is why the row that calls
/// this shows a confirmation rather than pretending the tips are back.
///
/// `@MainActor` rather than `nonisolated` like the other use cases: `TipsServicing` is
/// main-actor isolated, because TipKit's datastore is UI state and configuring it from anywhere
/// else would be a data race.
@MainActor
struct ResetTipsUseCase {
    private let tips: any TipsServicing

    init(tips: any TipsServicing) {
        self.tips = tips
    }

    func callAsFunction() {
        tips.resetAll()
    }
}
