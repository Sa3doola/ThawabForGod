//
//  UserNotificationService.swift
//  ThawabForGod
//

import Foundation
import UserNotifications

/// `UNUserNotificationCenter` behind the `NotificationService` protocol.
///
/// The only file in the app that imports UserNotifications. Its async API needs no bridging,
/// so this is a thin translation into the app's own three-case status.
@MainActor
final class UserNotificationService: NotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthorization {
        NotificationAuthorization(await center.notificationSettings().authorizationStatus)
    }

    @discardableResult
    func requestAuthorization() async -> NotificationAuthorization {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        } catch {
            // The system throws when it cannot even ask — an unsigned build, or a device
            // policy. Reminders are optional, so this degrades rather than propagates.
            return .denied
        }
    }
}

// MARK: - UserNotifications to domain

nonisolated private extension NotificationAuthorization {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        // Provisional delivers quietly to the notification centre, which is still enough for
        // prayer reminders to be useful.
        case .authorized, .provisional, .ephemeral:
            self = .authorized
        case .denied:
            self = .denied
        @unknown default:
            self = .denied
        }
    }
}
