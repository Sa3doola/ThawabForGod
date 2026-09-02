//
//  NotificationDoubles.swift
//  ThawabForGodTests
//

import Foundation
import UserNotifications
@testable import ThawabForGod

/// A notification centre that records instead of scheduling.
///
/// The reason `NotificationCenterClient` exists. `UNUserNotificationCenter.current()` is wired to
/// the real system: a test using it would leave requests pending on the machine, answer
/// differently depending on whether the test host had been granted permission, and collide with
/// any other test doing the same. This one is a dictionary.
///
/// Keyed by identifier, so it enforces the same replace-rather-than-duplicate rule the system
/// does — which is exactly the property the idempotency tests are checking.
@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    var status: UNAuthorizationStatus
    var authorizationOutcome: Bool
    var authorizationError: Error?

    private(set) var pending: [String: UNNotificationRequest] = [:]
    private(set) var authorizationRequestCount = 0
    private(set) var removeAllCount = 0
    private(set) var registeredCategories: Set<UNNotificationCategory> = []

    init(status: UNAuthorizationStatus = .authorized, authorizationOutcome: Bool = true) {
        self.status = status
        self.authorizationOutcome = authorizationOutcome
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestCount += 1
        if let authorizationError {
            throw authorizationError
        }
        return authorizationOutcome
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending[request.identifier] = request
    }

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        registeredCategories = categories
    }

    func pendingRequestIdentifiers() async -> [String] {
        pending.keys.sorted()
    }

    func removeAllPendingRequests() {
        removeAllCount += 1
        pending.removeAll()
    }
}

/// Fixed reminder text, so the scheduler's tests never need a bundle or a language.
@MainActor
struct StubReminderContent: ReminderContentProviding {
    func content(for reminder: PrayerReminder) -> ReminderContent {
        ReminderContent(
            title: reminder.prayer.rawValue,
            subtitle: "subtitle",
            body: "body",
            presentation: ReminderPresentation(
                subject: .prayer(reminder.prayer),
                date: reminder.date,
                body: "body"
            )
        )
    }
}

/// Artwork that is whatever the test says it is.
///
/// Defaults to `nil` — no picture — because that is the path the scheduler must survive, and
/// because writing a real PNG per request would put file I/O into a suite about scheduling. Set
/// `url` to a scratch file to exercise the attaching branch.
@MainActor
final class StubReminderArtwork: ReminderArtworkProviding {
    var url: URL?
    private(set) var requestedPrayers: [Prayer] = []

    init(url: URL? = nil) {
        self.url = url
    }

    func artwork(for prayer: Prayer) -> URL? {
        requestedPrayers.append(prayer)
        return url
    }
}

/// The state of the world, set by hand.
@MainActor
final class StubReminderInputs: ReminderInputsProviding {
    var inputs: ReminderInputs
    private(set) var readCount = 0

    init(
        coordinates: Coordinates? = .makkah,
        config: CalculationConfig = .default,
        enabledPrayers: Set<Prayer> = Set(Prayer.remindable)
    ) {
        self.inputs = ReminderInputs(
            coordinates: coordinates,
            config: config,
            enabledPrayers: enabledPrayers
        )
    }

    func currentInputs() async -> ReminderInputs {
        readCount += 1
        return inputs
    }
}

/// A notification service that answers however a test needs, and records what it was asked.
///
/// For the *callers* of the service — onboarding's permission step, Settings' status row —
/// rather than for the service's own tests, which drive the real one over
/// `FakeNotificationCenter`. It lives here rather than beside either of them because the service
/// is Core and both features borrow it.
@MainActor
final class MockNotificationService: NotificationService {
    var status: NotificationAuthorization
    var outcomeOfPrompt: NotificationAuthorization

    private(set) var authorizationRequestCount = 0
    private(set) var refreshCount = 0
    private(set) var cancelCount = 0

    init(
        status: NotificationAuthorization = .notDetermined,
        outcomeOfPrompt: NotificationAuthorization = .authorized
    ) {
        self.status = status
        self.outcomeOfPrompt = outcomeOfPrompt
    }

    func authorizationStatus() async -> NotificationAuthorization {
        status
    }

    @discardableResult
    func requestAuthorization() async -> NotificationAuthorization {
        authorizationRequestCount += 1
        status = outcomeOfPrompt
        return status
    }

    func refreshSchedule() async {
        refreshCount += 1
    }

    func cancelAll() {
        cancelCount += 1
    }
}
