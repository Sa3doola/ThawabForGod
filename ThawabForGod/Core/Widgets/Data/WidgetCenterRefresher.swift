//
//  WidgetCenterRefresher.swift
//  ThawabForGod
//

import Foundation
import WidgetKit

/// `WidgetCenter` behind `WidgetRefreshing` — the only file in the app target that imports
/// WidgetKit, the same way `PrayerTimeEngine` is the only one that imports Adhan.
///
/// Cheap to call and safe to call often: WidgetKit coalesces reloads and applies its own budget,
/// so the app's job is to be honest about *when* the inputs changed rather than to ration the
/// calls itself.
nonisolated struct WidgetCenterRefresher: WidgetRefreshing {
    init() {}

    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
