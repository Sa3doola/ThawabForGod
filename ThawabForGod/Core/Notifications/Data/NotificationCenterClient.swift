//
//  NotificationCenterClient.swift
//  ThawabForGod
//

import Foundation
import UserNotifications

/// The slice of `UNUserNotificationCenter` this app actually uses.
///
/// It names UserNotifications types, so it is infrastructure rather than Domain — the same
/// judgement `CorpusDatabaseProviding` makes about naming a GRDB type, and only the Data layer
/// may depend on it.
///
/// It exists so the scheduler can be tested at all. `UNUserNotificationCenter.current()` is a
/// process-wide singleton wired to the real notification system: a test that used it would
/// leave requests pending on the machine, behave differently depending on whether the test host
/// had been granted permission, and interfere with any other test doing the same.
///
/// `@MainActor` to match the service above it — see `UserNotificationService` for why that is
/// the right isolation rather than a habit.
@MainActor
protocol NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    func add(_ request: UNNotificationRequest) async throws

    /// The identifiers of everything still waiting to fire.
    func pendingRequestIdentifiers() async -> [String]

    func removeAllPendingRequests()
}

/// The real notification centre.
///
/// A pass-through with nothing to test, which is the point: every decision worth making sits
/// above it, and this file is the only place `UNUserNotificationCenter` is spoken to. Its async
/// API needs no bridging — the completion-handler variants are not used anywhere here.
@MainActor
struct UserNotificationCenterClient: NotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingRequestIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func removeAllPendingRequests() {
        // Pending only. Delivered notifications are the user's to clear — wiping the ones they
        // have not read yet because the app happened to reopen would lose them information.
        center.removeAllPendingNotificationRequests()
    }
}
