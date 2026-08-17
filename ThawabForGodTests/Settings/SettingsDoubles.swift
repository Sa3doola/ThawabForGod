//
//  SettingsDoubles.swift
//  ThawabForGodTests
//

import Foundation
import TipKit
@testable import ThawabForGod

/// Records what Settings asked of TipKit, without opening a datastore.
///
/// The real `TipsService` writes to disk and its `Tips.configure` is one-shot per process, so a
/// test that used it would leak into every other test in the run. What is under test here is only
/// that the row reaches the service at all.
@MainActor
final class SpyTipsService: TipsServicing {
    private(set) var configureCount = 0
    private(set) var resetCount = 0
    private(set) var invalidatedTipIDs: [String] = []

    func configure() {
        configureCount += 1
    }

    func resetAll() {
        resetCount += 1
    }

    func invalidate(_ tip: any Tip, reason: Tips.InvalidationReason) {
        invalidatedTipIDs.append(tip.id)
    }
}
