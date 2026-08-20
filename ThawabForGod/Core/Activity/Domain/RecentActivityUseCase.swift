//
//  RecentActivityUseCase.swift
//  ThawabForGod
//

import Foundation

/// Reading and writing where the user got to.
///
/// The write does not throw, and that is deliberate rather than lazy: recording an activity is a
/// *side effect* of doing something else — counting a dhikr, reading a verse — and a screen that
/// interrupted the thing the user came for to report that a convenience feature failed would have
/// its priorities backwards. The read does throw, because the section that calls it can sensibly
/// decide to show nothing.
nonisolated struct RecentActivityUseCase: Sendable {
    private let repository: any RecentActivityRepositoring

    init(repository: any RecentActivityRepositoring) {
        self.repository = repository
    }

    func recent() async throws -> [RecentActivity] {
        try await repository.recent()
    }

    func record(_ activity: RecentActivity) async {
        try? await repository.record(activity)
    }
}
