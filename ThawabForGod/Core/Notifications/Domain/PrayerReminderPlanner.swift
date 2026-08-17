//
//  PrayerReminderPlanner.swift
//  ThawabForGod
//

import Foundation

/// Works out which reminders should be pending right now.
///
/// **The whole reason this is a separate type**: iOS keeps at most 64 pending local
/// notifications per app and silently drops the rest, so "schedule a year of prayer times" is
/// not an option. What the app can do instead is keep a short rolling window filled and refill
/// it whenever it is opened — which turns the problem into an arithmetic one, and arithmetic
/// belongs in Domain where it can be tested without a notification centre.
///
/// Pure and `nonisolated`: it computes times through `PrayerTimeRepositoring`, which is the same
/// seam Home reads through, so reminders and the screen can never disagree about when Asr is.
nonisolated struct PrayerReminderPlanner: Sendable {

    /// How many days ahead to fill.
    ///
    /// Ten days × five obligatory prayers = fifty requests, which leaves fourteen of the
    /// system's sixty-four spare. The headroom is deliberate: it absorbs a future feature that
    /// wants a few notifications of its own without anyone having to rediscover the cap.
    static let windowDays = 10

    /// The system's hard limit. Not a target — a ceiling the plan is clamped to, so a bad
    /// window length can only ever schedule fewer reminders, never lose them at random.
    static let systemPendingLimit = 64

    private let repository: any PrayerTimeRepositoring
    private let windowDays: Int

    /// Gregorian and in the user's zone, for the same two reasons `PrayerTimeEngine` builds its
    /// own: day arithmetic must not run in Hijri on a device set to the Islamic calendar, and
    /// the zone decides which civil day an instant belongs to.
    private let calendar: Calendar

    init(
        repository: any PrayerTimeRepositoring,
        windowDays: Int = PrayerReminderPlanner.windowDays,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.repository = repository
        self.windowDays = windowDays

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// The reminders that should be pending, in chronological order.
    ///
    /// - Parameters:
    ///   - now: everything at or before this instant is left out — today's Fajr is history by
    ///     the afternoon, and scheduling it would either fire immediately or not at all.
    ///   - enabled: the prayers the user wants reminding of. Non-obligatory markers are dropped
    ///     whatever this says: sunrise ends Fajr's window rather than starting a prayer.
    func reminders(
        from now: Date,
        coordinates: Coordinates,
        config: CalculationConfig,
        enabled: Set<Prayer>
    ) -> [PrayerReminder] {
        let wanted = enabled.filter(\.isObligatory)
        guard !wanted.isEmpty, windowDays > 0 else { return [] }

        let today = calendar.startOfDay(for: now)
        var reminders: [PrayerReminder] = []

        for offset in 0..<windowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  // A day that cannot be computed is skipped rather than fatal: inside the
                  // polar circles some days genuinely have no Fajr, and the rest of the window
                  // is still worth scheduling.
                  let schedule = try? repository.schedule(for: coordinates, date: day, config: config) else {
                continue
            }

            let dayComponents = calendar.dateComponents([.year, .month, .day], from: schedule.day)

            for time in schedule.times where wanted.contains(time.prayer) && time.date > now {
                guard let id = ReminderIdentifier.make(day: dayComponents, prayer: time.prayer) else {
                    continue
                }
                reminders.append(PrayerReminder(prayer: time.prayer, date: time.date, id: id))
            }
        }

        // Sorted before clamping, so if the ceiling is ever reached it is the furthest-out
        // reminders that are dropped — the ones a later refresh will schedule anyway.
        return Array(reminders.sorted { $0.date < $1.date }.prefix(Self.systemPendingLimit))
    }
}
