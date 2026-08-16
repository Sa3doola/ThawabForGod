//
//  NotificationService.swift
//  ThawabForGod
//

import Foundation

/// Where the app stands with notification permission.
nonisolated enum NotificationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    /// Granted in some form — including provisional, which still lets reminders arrive.
    case authorized
}

/// Notification permission.
///
/// Scheduling lives behind this protocol too, but is not part of this slice: the rolling
/// prayer-reminder window is its own step, and nothing here should imply it already exists.
@MainActor
protocol NotificationService: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization

    /// Prompts for alert, sound and badge, and resolves once the user has answered.
    ///
    /// A refusal comes back as `.denied` rather than an error — the app must stay usable
    /// without reminders.
    @discardableResult
    func requestAuthorization() async -> NotificationAuthorization
}
