//
//  HomeViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the Home screen: today's times, which prayer is current, which is next, and a
/// countdown that ticks once a second.
///
/// It holds no astronomy of its own — that all lives behind `GetPrayerScheduleUseCase`, which
/// is what lets this type be tested by handing it a mock repository and a fake clock instead
/// of waiting on a real one.
@Observable
@MainActor
final class HomeViewModel {

    /// What the screen has to show. A single value rather than a scatter of optionals and
    /// flags, so the view can `switch` over it and no impossible combination is representable.
    enum Phase: Equatable {
        case loading
        case ready(NextPrayerState)
        /// The times could not be computed — the polar case. Not an error the user can fix,
        /// so it is a state rather than an alert.
        case unavailable
    }

    /// The whole of a "continue reading" card: where the reader stopped, and the chapter it is
    /// in. The chapter is optional because the position is the user's data and the chapter is the
    /// corpus's — a card that says the verse but not the name is still a way back into the text.
    struct ContinueReading: Equatable {
        let position: ReadingPosition
        let surah: Surah?
    }

    private(set) var phase: Phase = .loading

    /// How Home is arranged, as the user left it.
    ///
    /// Held whole rather than as a list of kinds, because the customization screen edits *this*
    /// value and hands it back — see `reloadLayout()`.
    private(set) var layout: HomeLayout

    /// The sections to draw, in order. Already filtered to what is visible and built.
    var sections: [HomeSectionKind] { layout.visibleSections }

    /// The shortcut circles to draw, in order.
    var shortcuts: [HomeShortcut] { layout.visibleShortcuts }

    /// Where the reader stopped in the Quran, or `nil` if they have not started.
    ///
    /// The section is absent rather than empty when this is `nil`: a card that says "continue"
    /// when there is nothing to continue is worse than no card — the same rule the Quran tab's
    /// own version of it follows.
    private(set) var continueReading: ContinueReading?

    /// Seconds remaining until the upcoming prayer.
    ///
    /// Kept apart from `phase` deliberately. Observation tracks reads per property, so a
    /// value that changes every second only invalidates the two labels that read it — the
    /// countdown and the progress bar — and the six prayer entries beside them are left alone.
    private(set) var countdown: TimeInterval = 0

    /// The city the times are being computed for, once anything has answered.
    ///
    /// `nil` is the normal state offline, and the card is built to be complete without it. The
    /// coordinates themselves come from GPS and need no network; only the *name* does, which is
    /// why this is the one value on the screen that is allowed to simply not arrive.
    private(set) var placeName: String?

    /// Today's Hijri date, and anything the Islamic calendar marks on it.
    ///
    /// Outside `Phase` on purpose: the times can fail to compute — the polar case — and the
    /// date still holds. A screen that says "prayer times unavailable" should not also lose
    /// track of what day it is.
    private(set) var hijriDate: HijriDate
    private(set) var todaysEvents: [IslamicEvent]

    /// The instant the screen was last recomputed from, which is what the header's date and
    /// greeting are drawn from.
    ///
    /// Stored rather than read from the clock on demand, because a computed property reading a
    /// clock observes nothing and the header would never redraw. It moves on every recomputation
    /// — a prayer arriving, midnight passing, the app returning to the foreground — which is
    /// often enough that a greeting is never more than one prayer out of date.
    private(set) var currentDate: Date

    /// How Home says hello, by the hour of `currentDate`.
    var greeting: HomeGreeting { HomeGreeting.at(currentDate, calendar: calendar) }

    /// How the times are being calculated right now.
    ///
    /// A window onto `CalculationSettings` rather than a copy, and the reason it is exposed at
    /// all: reading it inside a view registers a dependency on the shared object, so the view
    /// can watch it with `onChange` and ask for a recompute when Settings changes it. A stored
    /// copy would observe nothing.
    var config: CalculationConfig { calculation.config }

    @ObservationIgnored private let useCase: GetPrayerScheduleUseCase
    @ObservationIgnored private let getLayout: GetHomeLayoutUseCase
    @ObservationIgnored private let quranProgress: QuranProgressUseCase?
    @ObservationIgnored private let quran: GetQuranUseCase?
    @ObservationIgnored private var coordinates: Coordinates
    @ObservationIgnored private let locationService: (any LocationService)?
    @ObservationIgnored private let placeNames: (any PlaceNameResolving)?
    @ObservationIgnored private let reachability: (any NetworkReachability)?
    @ObservationIgnored private let calculation: CalculationSettings
    @ObservationIgnored private let hijriDates: any HijriDateServicing
    @ObservationIgnored private let tips: any HomeTipReporting
    @ObservationIgnored private let clock: any ClockService
    @ObservationIgnored private let calendar: Calendar

    /// - Parameters:
    ///   - coordinates: the starting point — onboarding's seeded position, or Makkah if it was
    ///     skipped. Held as the fallback for as long as no live fix has arrived, which is also
    ///     what lets every existing test exercise a schedule without touching `locationService`
    ///     at all.
    ///   - locationService: where a live position comes from, once `start()` asks for one. `nil`
    ///     in previews and in tests that only care about the astronomy, where a fixed
    ///     `coordinates` is enough. Never prompts for permission itself — onboarding already
    ///     did, so a fix here means "already authorized", not "ask while the user is reading
    ///     prayer times."
    ///   - placeNames: where the city label comes from. `nil` leaves the card without one, which
    ///     is a state it is built for rather than a degraded mode.
    ///   - reachability: consulted before asking for a name, so a device with the radio off does
    ///     not make a request that can only fail. Behind a protocol so a test can be offline
    ///     without unplugging the machine it runs on.
    ///   - calculation: the shared calculation choices. Not a plain `CalculationConfig`, because
    ///     Settings can change it while this screen is alive.
    ///   - hijriDates: the Hijri conversion and the events table.
    ///   - tips: where TipKit's rule inputs are reported. Behind a protocol so this type never
    ///     imports TipKit and its tests never open a datastore.
    ///   - getLayout: which sections this user wants, in what order.
    ///   - quranProgress: where the reader stopped, for the "continue reading" section, and
    ///   - quran: the chapter that verse is in. Both optional, and both a deliberate reach across
    ///     a feature boundary: the section is *about* the Quran, so Home composes that feature's
    ///     use cases rather than growing a second way to ask the same question. Wired at the
    ///     composition root like everything else; `nil` in previews and in tests about prayer
    ///     times, which leaves the section absent.
    ///   - clock: the time, and the heartbeat. Injected so tests can place themselves at any
    ///     moment of the day *and* step the countdown without sleeping — see `ClockService`.
    ///   - calendar: used only to notice that midnight has passed. Gregorian in the device's own
    ///     time zone, for the reason `PrayerTimeEngine` documents: `Calendar.current` on a device
    ///     set to the Islamic calendar answers in Hijri components, and the day boundary this
    ///     compares against is a civil one.
    init(
        useCase: GetPrayerScheduleUseCase,
        getLayout: GetHomeLayoutUseCase,
        coordinates: Coordinates,
        locationService: (any LocationService)? = nil,
        placeNames: (any PlaceNameResolving)? = nil,
        reachability: (any NetworkReachability)? = nil,
        hijriDates: any HijriDateServicing,
        calculation: CalculationSettings,
        tips: any HomeTipReporting = HomeTipReporter(),
        quranProgress: QuranProgressUseCase? = nil,
        quran: GetQuranUseCase? = nil,
        clock: any ClockService = SystemClockService(),
        calendar: Calendar = .gregorianLocal
    ) {
        self.useCase = useCase
        self.getLayout = getLayout
        self.quranProgress = quranProgress
        self.quran = quran
        self.coordinates = coordinates
        self.locationService = locationService
        self.placeNames = placeNames
        self.reachability = reachability
        self.calculation = calculation
        self.hijriDates = hijriDates
        self.tips = tips
        self.clock = clock
        self.calendar = calendar

        // Resolved here rather than left optional: unlike the schedule, the Hijri date needs
        // no computation that can fail, so the screen has one from its first frame and the
        // header never flickers in behind the loading state.
        let instant = clock.now
        self.currentDate = instant
        self.hijriDate = hijriDates.hijriComponents(for: instant)
        self.todaysEvents = hijriDates.islamicEvents(on: instant)

        // Read here rather than in `start()` so the stack is in its final order on the first
        // frame. It is a synchronous read of `UserDefaults`, not a trip to a database.
        self.layout = getLayout()
    }

    /// Loads the day, then ticks until cancelled.
    ///
    /// Structured on purpose: driven from the view's `.task`, SwiftUI cancels it when the
    /// screen goes away, which ends the stream below. There is no stored `Task` to own, no
    /// `[weak self]` dance, and no timer left running behind a screen nobody is looking at.
    func start() async {
        refresh()

        // One donation per appearance, which is what the "opened a few times" tip rule counts.
        // Before the loop, so a screen that is dismissed immediately still records the visit.
        await tips.homeOpened()

        // After the first refresh, not before: the screen has something to show — the seeded
        // point, or Makkah — while this is in flight, rather than sitting on `.loading` for a
        // fix that might never come.
        await resolveLiveLocation()

        // Beside the heartbeat rather than before it. Reverse geocoding waits on a server, and a
        // slow answer — or one that never comes — must not be able to hold up a countdown. The
        // `async let` is awaited below so the child is still structured: cancelling the screen's
        // task cancels this too.
        async let name: Void = resolvePlaceName()
        async let reading: Void = loadContinueReading()

        for await _ in clock.ticks(every: .seconds(1)) {
            tick()
        }

        await name
        await reading
    }

    /// Re-reads the arrangement, for when the customization screen has just been dismissed.
    ///
    /// Cheap enough to do unconditionally: one `UserDefaults` read and a decode, against a screen
    /// the user has just spent time arranging.
    func reloadLayout() {
        layout = getLayout()
    }

    /// Loads where the reader stopped in the Quran.
    ///
    /// Silent on failure, and the section simply stays absent. This is somebody else's store and
    /// a nice-to-have besides — a Home screen that could not read it should still show the times,
    /// which is what it is for.
    private func loadContinueReading() async {
        guard let quranProgress, let quran, let position = try? await quranProgress.lastRead()
        else {
            continueReading = nil
            return
        }

        continueReading = ContinueReading(
            position: position,
            surah: try? await quran.surah(position.reference.surah)
        )
    }

    /// Reads a live fix, if the app has a location service and is already authorized.
    ///
    /// One-shot, the same as `LocationService` itself is — no continuous tracking, matching
    /// `QiblaViewModel`'s use of the same protocol. A denial, an unauthorized state, or a
    /// failed reading all leave `coordinates` exactly where it was: the seeded point remains a
    /// defensible placeholder for prayer times in a way it never was for the Qibla arrow.
    private func resolveLiveLocation() async {
        guard let locationService,
              locationService.authorization == .authorized,
              let live = try? await locationService.currentCoordinates(),
              live != coordinates else {
            return
        }

        coordinates = live
        refresh()
    }

    /// Puts a city on the card, if there is a network and anything answers.
    ///
    /// Runs after the live fix so it names where the user actually is rather than where they
    /// were seeded. Nothing waits on it and nothing retries: a name that misses arrives on the
    /// next appearance of the screen, and until then the card is drawn without one.
    private func resolvePlaceName() async {
        guard let placeNames, reachability?.isOnline ?? true else { return }

        placeName = await placeNames.placeName(for: coordinates)
    }

    /// Recomputes everything from the current instant.
    func refresh() {
        let instant = clock.now
        currentDate = instant

        // Ahead of the schedule, and outside the `do`: the date is what the day is, whether or
        // not the times worked out. It also lets the roll into a new day — which `tick()`
        // triggers by calling back into here — carry the header along with the times.
        hijriDate = hijriDates.hijriComponents(for: instant)
        todaysEvents = hijriDates.islamicEvents(on: instant)

        do {
            let schedule = try useCase.schedule(for: coordinates, date: instant, config: config)
            let upcoming = try useCase.upcomingPrayer(for: coordinates, at: instant, config: config)

            phase = .ready(
                NextPrayerState(
                    schedule: schedule,
                    currentPrayer: schedule.currentPrayer(at: instant),
                    upcoming: upcoming,
                    // `try?`, and deliberately so: the near end of the progress bar is the only
                    // thing here that can need a *second* day's times, and a bar that cannot be
                    // anchored is a bar drawn empty — not a card that fails to appear.
                    previous: try? useCase.previousPrayer(
                        for: coordinates, at: instant, config: config
                    )
                )
            )
            countdown = max(0, upcoming.date.timeIntervalSince(instant))
            // Reported here rather than read by the tip, so eligibility is a plain flag and
            // TipKit never learns what a prayer schedule is.
            tips.countingDownToTomorrow(upcoming.isTomorrow)
        } catch {
            phase = .unavailable
            countdown = 0
            tips.countingDownToTomorrow(false)
        }
    }

    /// Advances the countdown by one reading of the clock.
    ///
    /// Internal rather than private so tests can step time deliberately instead of sleeping.
    func tick() {
        guard case .ready(let state) = phase else { return }

        let instant = clock.now
        let remaining = state.upcoming.date.timeIntervalSince(instant)

        // Two ways the screen goes stale, and both want the same answer: recompute, never
        // decrement. The prayer has arrived — move the highlight and retarget the countdown,
        // including the roll into tomorrow's Fajr once Isha passes. Or midnight has passed while
        // the countdown was still running, which is the case a decrementing timer cannot see:
        // between Isha and Fajr the countdown is perfectly healthy and the six entries beneath it
        // belong to a day that ended hours ago.
        guard remaining > 0, calendar.isDate(instant, inSameDayAs: state.schedule.day) else {
            refresh()
            return
        }

        countdown = remaining
    }
}
