//
//  PrayerReminderPlannerTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The window's arithmetic, tested as the pure Swift it is — no notification centre in sight.
///
/// Everything runs in GMT so the fixtures' round hours and the planner's day boundaries agree
/// wherever the suite happens to be run.
struct PrayerReminderPlannerTests {

    private let firstDay = PrayerTimeFixtures.day(2026, 6, 15)

    /// Fixture days are fajr 05:00 · sunrise 06:30 · dhuhr 12:00 · asr 15:30 · maghrib 18:00 ·
    /// isha 19:30, repeated for as many days as asked for.
    private func planner(days: Int = 14, windowDays: Int = PrayerReminderPlanner.windowDays) -> PrayerReminderPlanner {
        let dates = (0..<days).compactMap {
            PrayerTimeFixtures.calendar.date(byAdding: .day, value: $0, to: firstDay)
        }

        return PrayerReminderPlanner(
            repository: PrayerTimeFixtures.repository(days: dates),
            windowDays: windowDays,
            timeZone: .gmt
        )
    }

    private func plan(
        _ planner: PrayerReminderPlanner,
        at now: Date,
        enabled: Set<Prayer> = Set(Prayer.remindable)
    ) -> [PrayerReminder] {
        planner.reminders(from: now, coordinates: .makkah, config: .default, enabled: enabled)
    }

    // MARK: Windowing

    @Test func aFullWindowIsTenDaysOfFivePrayers() {
        let reminders = plan(planner(), at: firstDay)

        #expect(reminders.count == 50)
        #expect(Set(reminders.map(\.prayer)) == Set(Prayer.remindable))
    }

    /// Sunrise sits on the same timeline and comes back in every schedule, but it starts no
    /// prayer — so there is nothing to remind anyone to do.
    @Test func sunriseIsNeverScheduled() {
        let reminders = plan(planner(), at: firstDay, enabled: Set(Prayer.allCases))

        #expect(reminders.allSatisfy { $0.prayer != .sunrise })
        #expect(reminders.count == 50)
    }

    /// The constraint the whole design exists for: iOS keeps 64 pending notifications and drops
    /// the rest silently. A window that asks for more must be clamped, not trusted.
    @Test func theSystemLimitIsNeverExceeded() {
        let reminders = plan(planner(days: 40, windowDays: 40), at: firstDay)

        #expect(reminders.count == PrayerReminderPlanner.systemPendingLimit)
    }

    /// And what survives the clamp is the *soonest* — the far end of an over-long window is what
    /// a later refresh would schedule anyway.
    @Test func clampingDropsTheFurthestOutReminders() {
        let reminders = plan(planner(days: 40, windowDays: 40), at: firstDay)
        let dates = reminders.map(\.date)

        #expect(dates == dates.sorted())
        #expect(dates.first == PrayerTimeFixtures.instant(firstDay, hour: 5))
    }

    @Test func remindersComeBackInChronologicalOrder() {
        let dates = plan(planner(), at: firstDay).map(\.date)

        #expect(dates == dates.sorted())
    }

    // MARK: Today

    /// A reminder for a prayer that has already passed either fires immediately or not at all.
    /// Both are wrong, so today contributes only what is still ahead.
    @Test func prayersAlreadyPastTodayAreSkipped() {
        // 13:00 — fajr, sunrise and dhuhr are behind us; asr, maghrib and isha are not.
        let reminders = plan(planner(), at: PrayerTimeFixtures.instant(firstDay, hour: 13))

        let today = reminders.filter { $0.id.contains("2026-06-15") }
        #expect(today.map(\.prayer) == [.asr, .maghrib, .isha])
        // Three today, then nine untouched days behind it.
        #expect(reminders.count == 3 + (9 * 5))
    }

    /// The boundary itself: a prayer whose moment is exactly now has arrived, and announcing it
    /// is what the notification would be doing a second too late.
    @Test func aPrayerAtThisExactInstantIsNotScheduled() {
        let asr = PrayerTimeFixtures.instant(firstDay, hour: 15, minute: 30)
        let reminders = plan(planner(), at: asr)

        #expect(!reminders.contains { $0.date == asr })
    }

    @Test func aDayWithNothingLeftContributesNothing() {
        let reminders = plan(planner(), at: PrayerTimeFixtures.instant(firstDay, hour: 23))

        #expect(!reminders.contains { $0.id.contains("2026-06-15") })
        #expect(reminders.count == 9 * 5)
    }

    // MARK: Toggles

    @Test func onlyTheEnabledPrayersAreScheduled() {
        let reminders = plan(planner(), at: firstDay, enabled: [.fajr, .maghrib])

        #expect(Set(reminders.map(\.prayer)) == [.fajr, .maghrib])
        #expect(reminders.count == 20)
    }

    @Test func disablingEveryPrayerSchedulesNothing() {
        #expect(plan(planner(), at: firstDay, enabled: []).isEmpty)
    }

    // MARK: Identifiers

    /// Stability is what makes a refresh idempotent rather than cumulative: re-adding under an
    /// identifier that is already pending replaces it.
    @Test func identifiersAreStableAcrossPlans() {
        let first = plan(planner(), at: firstDay).map(\.id)
        let second = plan(planner(), at: firstDay).map(\.id)

        #expect(first == second)
    }

    @Test func identifiersAreUnique() {
        let ids = plan(planner(), at: firstDay).map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    @Test func identifiersReadBackAsTheirDayAndPrayer() throws {
        let reminder = try #require(plan(planner(), at: firstDay).first)
        #expect(reminder.id == "prayer-reminder.2026-06-15.fajr")

        let parsed = try #require(ReminderIdentifier.parse(reminder.id))
        #expect(parsed.day == "2026-06-15")
        #expect(parsed.prayer == .fajr)
    }

    @Test func somethingElsesIdentifierIsNotMistakenForOurs() {
        #expect(ReminderIdentifier.parse("tip.2026-06-15.fajr") == nil)
        #expect(ReminderIdentifier.parse("prayer-reminder.2026-06-15") == nil)
        #expect(ReminderIdentifier.parse("prayer-reminder.2026-06-15.tahajjud") == nil)
    }

    // MARK: Failure and degenerate input

    /// Inside the polar circles some days genuinely have no Fajr. One of them must cost that
    /// day's reminders, not the window's.
    @Test func aDayThatCannotBeComputedIsSkipped() {
        let missingSecondDay = [0, 2, 3].compactMap {
            PrayerTimeFixtures.calendar.date(byAdding: .day, value: $0, to: firstDay)
        }
        let planner = PrayerReminderPlanner(
            repository: PrayerTimeFixtures.repository(days: missingSecondDay),
            windowDays: 4,
            timeZone: .gmt
        )

        let reminders = plan(planner, at: firstDay)

        #expect(reminders.count == 15)
        #expect(!reminders.contains { $0.id.contains("2026-06-16") })
    }

    @Test func aZeroLengthWindowSchedulesNothing() {
        #expect(plan(planner(windowDays: 0), at: firstDay).isEmpty)
    }

    // MARK: Calculation config

    // MARK: Calculation config
    //
    // Against the real engine rather than the fixtures, because the fixtures serve the same
    // times whatever they are asked for — and what these two check is precisely that the config
    // reaches the calculation.
    //
    // Makkah rather than a high latitude: in mid-June, London has no true astronomical twilight,
    // so Fajr and Isha have no solution at 18° and the engine correctly refuses to invent one.
    // That is a real property, tested where it belongs in `PrayerTimeEngineTests`; here it would
    // only mean both sides came back empty and the comparison proved nothing.

    private func realEnginePlanner() -> PrayerReminderPlanner {
        PrayerReminderPlanner(
            repository: PrayerTimeRepository(engine: PrayerTimeEngine(timeZone: .gmt)),
            windowDays: 1,
            timeZone: .gmt
        )
    }

    private func firstReminder(
        _ prayer: Prayer,
        _ config: CalculationConfig
    ) throws -> Date {
        let reminders = realEnginePlanner().reminders(
            from: firstDay,
            coordinates: .makkah,
            config: config,
            enabled: [prayer]
        )

        return try #require(reminders.first?.date)
    }

    /// The Hanafi shadow rule is two object-lengths rather than one, so Asr lands later.
    @Test func theMadhabMovesTheAsrReminder() throws {
        let shafi = try firstReminder(.asr, CalculationConfig(method: .muslimWorldLeague, madhab: .shafi))
        let hanafi = try firstReminder(.asr, CalculationConfig(method: .muslimWorldLeague, madhab: .hanafi))

        #expect(shafi < hanafi)
    }

    /// Different authorities, different twilight angles, different Fajr.
    @Test func theMethodMovesTheFajrReminder() throws {
        let muslimWorldLeague = try firstReminder(.fajr, .default)
        let egyptian = try firstReminder(.fajr, CalculationConfig(method: .egyptian, madhab: .shafi))

        #expect(muslimWorldLeague != egyptian)
    }
}
