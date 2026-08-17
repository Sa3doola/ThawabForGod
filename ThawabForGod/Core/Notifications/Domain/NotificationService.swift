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

/// Notification permission, and the rolling window of prayer reminders.
///
/// One protocol for both because they are one decision: there is nothing to schedule without
/// permission, and no reason to hold permission without scheduling. Keeping them together also
/// keeps this the single place the app asks — onboarding prompts through here, Settings reads
/// the status through here, and nothing else touches the notification centre.
///
/// The status is the app's own three-case enum rather than `UNAuthorizationStatus`: Domain does
/// not import UserNotifications, and callers only ever branch on the three outcomes.
@MainActor
protocol NotificationService: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization

    /// Prompts for alert, sound and badge, and resolves once the user has answered.
    ///
    /// A refusal comes back as `.denied` rather than an error — the app must stay usable
    /// without reminders.
    @discardableResult
    func requestAuthorization() async -> NotificationAuthorization

    /// Rebuilds the pending window from scratch: recompute, clear, refill.
    ///
    /// Safe to call as often as anything likes — on launch, on returning to the foreground,
    /// after any change in Settings. Reminders carry stable identifiers, so a re-add replaces
    /// rather than duplicates and the pending set converges on the same answer however many
    /// refreshes overlap.
    ///
    /// Silent about failure by design. A refresh that cannot run — permission refused, position
    /// unknown — leaves the user with no reminders, which is the correct outcome and not
    /// something to interrupt them about.
    func refreshSchedule() async

    /// Drops every pending reminder. What a refusal, or a revoked permission, leaves behind.
    func cancelAll()
}
