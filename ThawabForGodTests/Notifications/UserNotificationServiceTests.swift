//
//  UserNotificationServiceTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
import UserNotifications
@testable import ThawabForGod

/// Every system status the app maps, and what it maps to.
///
/// At file scope rather than as a static on the suite: `@Test(arguments:)` cannot reference a
/// member of the very type whose macro is being expanded — that is a circular reference the
/// compiler reports as an unknown attribute.
///
/// `.ephemeral` is App Clips only and **does not exist on macOS**, so it is appended rather than
/// listed inline. Without that the whole test target fails to compile for the Mac, which is how
/// it went unnoticed: the documented test command targets the iOS simulator, and CI runs the Mac
/// as a build only.
private let authorizationCases: [(UNAuthorizationStatus, NotificationAuthorization)] = {
    var cases: [(UNAuthorizationStatus, NotificationAuthorization)] = [
        (.notDetermined, .notDetermined),
        (.authorized, .authorized),
        (.provisional, .authorized),
        (.denied, .denied)
    ]

    #if os(iOS)
    cases.append((.ephemeral, .authorized))
    #endif

    return cases
}()

/// The scheduler's own half: permission, the order of operations, and the translation into
/// `UNNotificationRequest`. The window's arithmetic is `PrayerReminderPlannerTests`'.
@MainActor
struct UserNotificationServiceTests {

    private let firstDay = PrayerTimeFixtures.day(2026, 6, 15)

    private struct Context {
        let service: UserNotificationService
        let center: FakeNotificationCenter
        let inputs: StubReminderInputs
        let artwork: StubReminderArtwork
    }

    private func makeContext(
        at now: Date? = nil,
        status: UNAuthorizationStatus = .authorized,
        coordinates: Coordinates? = .makkah,
        enabledPrayers: Set<Prayer> = Set(Prayer.remindable),
        artworkURL: URL? = nil
    ) -> Context {
        let center = FakeNotificationCenter(status: status)
        let inputs = StubReminderInputs(coordinates: coordinates, enabledPrayers: enabledPrayers)
        let artwork = StubReminderArtwork(url: artworkURL)
        let dates = (0..<14).compactMap {
            PrayerTimeFixtures.calendar.date(byAdding: .day, value: $0, to: firstDay)
        }
        let instant = now ?? firstDay

        let service = UserNotificationService(
            center: center,
            planner: PrayerReminderPlanner(
                repository: PrayerTimeFixtures.repository(days: dates),
                timeZone: .gmt
            ),
            content: StubReminderContent(),
            inputs: inputs,
            artwork: artwork,
            timeZone: .gmt,
            now: { instant }
        )

        return Context(service: service, center: center, inputs: inputs, artwork: artwork)
    }

    // MARK: Permission

    @Test func grantedPermissionComesBackAuthorized() async {
        let context = makeContext()
        context.center.authorizationOutcome = true

        #expect(await context.service.requestAuthorization() == .authorized)
        #expect(context.center.authorizationRequestCount == 1)
    }

    @Test func refusedPermissionComesBackDenied() async {
        let context = makeContext()
        context.center.authorizationOutcome = false

        #expect(await context.service.requestAuthorization() == .denied)
    }

    /// The system throws when it cannot even ask — an unsigned build, a device policy. Reminders
    /// are optional, so that degrades rather than propagates.
    @Test func anUnaskableSystemIsTreatedAsARefusal() async {
        let context = makeContext()
        context.center.authorizationError = HTTPError.transport(URLError(.notConnectedToInternet))

        #expect(await context.service.requestAuthorization() == .denied)
    }

    /// Provisional authorization still delivers, quietly, which is enough for a reminder.
    ///
    /// `.ephemeral` is App Clips only and does not exist on macOS, so the case is added rather
    /// than listed inline — without that the whole test target fails to *compile* for macOS,
    /// which is how this went unnoticed: the documented test command targets the iOS simulator
    /// and CI runs the Mac as a build only.
    @Test(arguments: authorizationCases)
    func systemStatusMapsOntoTheAppsThreeCases(
        _ status: UNAuthorizationStatus,
        _ expected: NotificationAuthorization
    ) async {
        let context = makeContext(status: status)

        #expect(await context.service.authorizationStatus() == expected)
    }

    // MARK: Refreshing

    @Test func refreshingFillsTheWindow() async {
        let context = makeContext()

        await context.service.refreshSchedule()

        #expect(context.center.pending.count == 50)
    }

    /// The property the whole design rests on. Two refreshes must leave the same pending set —
    /// not a doubled one, and not one over the system's ceiling.
    @Test func refreshingTwiceLeavesTheSameSet() async {
        let context = makeContext()

        await context.service.refreshSchedule()
        let first = await context.center.pendingRequestIdentifiers()

        await context.service.refreshSchedule()
        let second = await context.center.pendingRequestIdentifiers()

        #expect(first == second)
        #expect(second.count == 50)
        #expect(second.count <= PrayerReminderPlanner.systemPendingLimit)
    }

    /// Clear then refill, in that order, so a stale window is never left alongside a fresh one.
    @Test func refreshingClearsBeforeItRefills() async {
        let context = makeContext()

        await context.service.refreshSchedule()

        #expect(context.center.removeAllCount == 1)
    }

    /// The inputs are read on every refresh rather than captured once — the user can move, and
    /// the method can change while the app is open.
    @Test func everyRefreshRereadsTheWorld() async {
        let context = makeContext()

        await context.service.refreshSchedule()
        context.inputs.inputs = ReminderInputs(
            coordinates: .makkah,
            config: .default,
            enabledPrayers: [.fajr]
        )
        await context.service.refreshSchedule()

        #expect(context.inputs.readCount == 2)
        #expect(context.center.pending.count == 10)
    }

    @Test func disablingEveryPrayerEmptiesThePendingSet() async {
        let context = makeContext(enabledPrayers: [])

        await context.service.refreshSchedule()

        #expect(context.center.pending.isEmpty)
    }

    // MARK: Refusing to schedule

    /// Permission can be revoked in the Settings app between launches, and a window left pending
    /// for it to come back would be a window nobody is refreshing.
    @Test(arguments: [UNAuthorizationStatus.denied, .notDetermined])
    func withoutPermissionNothingIsScheduled(_ status: UNAuthorizationStatus) async {
        let context = makeContext(status: status)

        await context.service.refreshSchedule()

        #expect(context.center.pending.isEmpty)
        #expect(context.center.removeAllCount == 1)
    }

    /// The judgement call this slice makes: no position, no reminders. Home can fall back to
    /// Makkah because a wrong time on screen is visibly wrong; a notification firing at Makkah's
    /// Maghrib on a phone in London arrives while nobody is looking at the screen to notice.
    @Test func withoutCoordinatesNothingIsScheduled() async {
        let context = makeContext(coordinates: nil)

        await context.service.refreshSchedule()

        #expect(context.center.pending.isEmpty)
    }

    @Test func cancellingClearsThePendingSet() async {
        let context = makeContext()
        await context.service.refreshSchedule()

        context.service.cancelAll()

        #expect(context.center.pending.isEmpty)
    }

    // MARK: The requests themselves

    @Test func eachRequestFiresAtItsPrayersTime() async throws {
        let context = makeContext()

        await context.service.refreshSchedule()

        let fajr = try #require(context.center.pending["prayer-reminder.2026-06-15.fajr"])
        let trigger = try #require(fajr.trigger as? UNCalendarNotificationTrigger)

        #expect(trigger.dateComponents.year == 2026)
        #expect(trigger.dateComponents.month == 6)
        #expect(trigger.dateComponents.day == 15)
        #expect(trigger.dateComponents.hour == 5)
        #expect(trigger.dateComponents.minute == 0)
        // Non-repeating: prayer times move daily, so every occurrence is its own request.
        #expect(trigger.repeats == false)
    }

    @Test func eachRequestCarriesTheProvidedText() async throws {
        let context = makeContext()

        await context.service.refreshSchedule()

        let maghrib = try #require(context.center.pending["prayer-reminder.2026-06-15.maghrib"])

        #expect(maghrib.content.title == Prayer.maghrib.rawValue)
        #expect(maghrib.content.subtitle == "subtitle")
        #expect(maghrib.content.body == "body")
    }

    // MARK: The custom presentation

    /// Without this identifier iOS never consults the content extension, and every reminder falls
    /// back to the system's own layout — silently, and identically to the extension being absent.
    @Test func eachRequestIsFiledUnderTheReminderCategory() async throws {
        let context = makeContext()

        await context.service.refreshSchedule()

        let maghrib = try #require(context.center.pending["prayer-reminder.2026-06-15.maghrib"])

        #expect(maghrib.content.categoryIdentifier == ReminderCategory.prayer.identifier)
    }

    @Test func eachRequestCarriesADecodablePayload() async throws {
        let context = makeContext()

        await context.service.refreshSchedule()

        let maghrib = try #require(context.center.pending["prayer-reminder.2026-06-15.maghrib"])
        let payload = try #require(ReminderPresentation(userInfo: maghrib.content.userInfo))

        #expect(payload.subject == .prayer(.maghrib))
        #expect(payload.body == "body")
        // The card formats this itself, so it has to be the prayer's own instant rather than a
        // string somebody already rendered — which is the whole reason the payload carries a
        // `Date` and not a time.
        #expect(payload.date == firingDate(of: try #require(maghrib.trigger)))
    }

    /// The categories have to be registered before the system will route anything to the
    /// extension, and the refresh is the only place that happens.
    @Test func refreshingRegistersTheCategories() async {
        let context = makeContext()

        await context.service.refreshSchedule()

        #expect(context.center.registeredCategories == ReminderCategory.registrations)
    }

    /// Registration happens even when there is nothing to schedule. A reader who has not granted
    /// permission yet may grant it from the Settings app, at which point the first delivery must
    /// already know where to go.
    @Test func categoriesAreRegisteredEvenWithoutPermission() async {
        let context = makeContext(status: .denied)

        await context.service.refreshSchedule()

        #expect(context.center.registeredCategories == ReminderCategory.registrations)
    }

    // MARK: Artwork

    @Test func artworkIsAskedForOncePerReminder() async {
        let context = makeContext()

        await context.service.refreshSchedule()

        #expect(context.artwork.requestedPrayers.count == context.center.pending.count)
    }

    /// The trade this branch exists to make: losing the reminder to save the picture is the wrong
    /// way round, so a provider that cannot draw must not cost the window.
    @Test func aReminderSurvivesArtworkItCannotDraw() async throws {
        let context = makeContext(artworkURL: nil)

        await context.service.refreshSchedule()

        let maghrib = try #require(context.center.pending["prayer-reminder.2026-06-15.maghrib"])

        #expect(maghrib.content.attachments.isEmpty)
        #expect(context.center.pending.count == 50)
    }

    /// A URL naming nothing is the same trade one step further on: `UNNotificationAttachment`
    /// throws, and the request still has to be added.
    @Test func aReminderSurvivesAnArtworkFileThatIsNotThere() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")

        let context = makeContext(artworkURL: missing)

        await context.service.refreshSchedule()

        let maghrib = try #require(context.center.pending["prayer-reminder.2026-06-15.maghrib"])

        #expect(maghrib.content.attachments.isEmpty)
        #expect(context.center.pending.count == 50)
    }

    /// The instant a calendar trigger will fire at, read back out through the same calendar the
    /// service built it with.
    private func firingDate(of trigger: UNNotificationTrigger) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        return (trigger as? UNCalendarNotificationTrigger)
            .flatMap { calendar.date(from: $0.dateComponents) }
    }

    /// Today's past prayers are the planner's rule, asserted here as well because it is the
    /// pending set — what the system will actually deliver — that has to be right.
    @Test func aRefreshLateInTheDaySchedulesOnlyWhatIsLeft() async {
        let context = makeContext(at: PrayerTimeFixtures.instant(firstDay, hour: 13))

        await context.service.refreshSchedule()

        let today = context.center.pending.keys.filter { $0.contains("2026-06-15") }
        #expect(Set(today) == [
            "prayer-reminder.2026-06-15.asr",
            "prayer-reminder.2026-06-15.maghrib",
            "prayer-reminder.2026-06-15.isha"
        ])
    }
}
