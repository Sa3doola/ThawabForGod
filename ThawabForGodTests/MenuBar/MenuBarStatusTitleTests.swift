//
//  MenuBarStatusTitleTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The status item's title: the slot that keeps it still, and the ladder it climbs down as the
/// menu bar fills up.
///
/// All of it is reachable from the simulator because none of it imports AppKit — which is the
/// reason the logic is here rather than in `MenuBarController`. What the controller adds is the
/// monospaced-digit font that makes equal character counts equal widths, and the measurement of
/// the free bar; neither is a decision, and neither is testable without a menu bar to put an item
/// in.
@MainActor
struct MenuBarStatusTitleTests {

    private let today = PrayerTimeFixtures.day(2026, 6, 15)
    private let tomorrow = PrayerTimeFixtures.day(2026, 6, 16)
    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)

    private func makeViewModel(
        at now: Date,
        digits: NumberSystem? = nil,
        located: Bool = true
    ) -> MenuBarPanelViewModel {
        var doubles: [SettingsKey: Double] = [:]
        if located {
            doubles[.latitude] = london.latitude
            doubles[.longitude] = london.longitude
        }

        let store = InMemorySettingsStore(
            strings: digits.map { [.numberSystem: $0.rawValue] } ?? [:],
            doubles: doubles
        )

        return MenuBarPanelViewModel(
            timeline: NextPrayerTimeline(
                schedule: GetPrayerScheduleUseCase(
                    repository: PrayerTimeFixtures.repository(days: [today, tomorrow]),
                    calendar: PrayerTimeFixtures.calendar
                ),
                settingsStore: store,
                timeZone: .gmt
            ),
            l10n: LocalizationManager(
                settingsStore: store,
                numberFormatting: LocaleNumberFormattingService(),
                timeFormatting: LocaleTimeFormattingService(),
                language: .english
            ),
            now: now
        )
    }

    // MARK: The format

    /// `h:mm` above the hour, `mm:ss` inside it. The seconds arrive at the one moment they start
    /// to matter, which is also the only moment the slot is allowed to change shape.
    @Test func theCountdownShowsSecondsOnlyInsideTheFinalHour() {
        let formatter = LocaleTimeFormattingService()

        // Two hours and change: hours and minutes, no seconds to twitch.
        #expect(formatter.briefCountdownString(from: 7_245, system: .latin).contains("2:00"))
        // Fifty-nine minutes: the pair shifts down.
        #expect(formatter.briefCountdownString(from: 3_545, system: .latin).contains("59:05"))
    }

    /// Two components, always — which is what leaves the slot with only one transition to survive
    /// rather than one per digit.
    @Test func theCountdownIsAlwaysTwoComponents() {
        let formatter = LocaleTimeFormattingService()

        for seconds in stride(from: 0, through: 12 * 3_600, by: 37) {
            let text = formatter.briefCountdownString(from: TimeInterval(seconds), system: .latin)
            let colons = text.filter { $0 == ":" }.count

            #expect(colons == 1, "\(seconds)s rendered as \(text)")
        }
    }

    // MARK: The slot

    /// **The assertion this whole slice exists for.** Across a full day of countdown, in either
    /// digit system, the padded title is always exactly as wide as the slot — so the prayer name
    /// beside it never shuffles.
    @Test(arguments: [NumberSystem.latin, NumberSystem.arabicIndic])
    func thePaddedCountdownIsTheSameWidthAtEveryInstant(system: NumberSystem) {
        let formatter = LocaleTimeFormattingService()
        let slot = MenuBarStatusSlot.visibleLength(
            of: formatter.briefCountdownString(from: MenuBarStatusSlot.widestInterval, system: system)
        )

        for seconds in stride(from: 0, through: 12 * 3_600, by: 17) {
            let padded = MenuBarStatusSlot.padded(
                formatter.briefCountdownString(from: TimeInterval(seconds), system: system),
                toVisibleLength: slot
            )

            #expect(
                MenuBarStatusSlot.visibleLength(of: padded) == slot,
                "\(seconds)s in \(system) rendered as \(padded)"
            )
        }
    }

    /// The directional isolates are controls and occupy no width. Counting them would make the
    /// slot two characters too narrow and the padding a no-op.
    @Test func theIsolatesDoNotCountTowardsTheWidth() {
        let formatter = LocaleTimeFormattingService()
        let text = formatter.briefCountdownString(from: 3_661, system: .latin)

        // "1:01" — four characters the reader sees, wrapped in two they do not.
        #expect(MenuBarStatusSlot.visibleLength(of: text) == 4)
        #expect(text.unicodeScalars.count == 6)
    }

    /// The padding goes on the leading side, so the digits end where they began and nothing sits
    /// to their right.
    @Test func paddingIsLeadingAndOutsideTheIsolates() {
        let padded = MenuBarStatusSlot.padded("\u{2066}4:12\u{2069}", toVisibleLength: 5)

        #expect(padded.hasPrefix(MenuBarStatusSlot.figureSpace))
        #expect(padded.hasSuffix("\u{2069}"))
        #expect(MenuBarStatusSlot.visibleLength(of: padded) == 5)
    }

    /// A string already at the slot is returned untouched rather than padded to something wider.
    @Test func aFullWidthCountdownIsNotPaddedFurther() {
        let text = "\u{2066}12:34\u{2069}"

        #expect(MenuBarStatusSlot.padded(text, toVisibleLength: 5) == text)
    }

    // MARK: The ladder

    /// The name goes first, then the symbol. The time never does — until the rung where nothing
    /// but a symbol fits, and half a countdown would be worse than none.
    @Test func theLadderDropsThePartsInOrder() {
        let style = MenuBarStatusStyle.automatic

        #expect(style.rung(freeWidth: 900) == .full)
        #expect(style.rung(freeWidth: 260) == .symbolAndTime)
        #expect(style.rung(freeWidth: 150) == .timeOnly)
        #expect(style.rung(freeWidth: 40) == .symbolOnly)
    }

    /// An unmeasured bar is a roomy one. Guessing small would mean every launch visibly flickered
    /// from a bare symbol up to the full title — and a status item is on screen at all times, so
    /// anything that moves in it is something the eye is dragged to.
    @Test func anUnmeasuredBarIsTreatedAsRoomy() {
        #expect(MenuBarStatusStyle.automatic.rung(freeWidth: nil) == .full)
    }

    /// A pinned style ignores the bar entirely — which is the whole reason it is offered. Someone
    /// whose menu bar is permanently crowded should be able to choose once.
    @Test func aPinnedStyleIgnoresTheWidth() {
        #expect(MenuBarStatusStyle.full.rung(freeWidth: 10) == .full)
        #expect(MenuBarStatusStyle.timeOnly.rung(freeWidth: 4_000) == .timeOnly)
        #expect(MenuBarStatusStyle.symbolOnly.rung(freeWidth: 4_000) == .symbolOnly)
    }

    /// The prayer's name as *this bundle* resolves it.
    ///
    /// Not the literal `"Maghrib"`. `LocalizationManager.string(_:)` reads the app bundle, which
    /// picks its `.lproj` from the host process's preferred languages — so on a simulator set to
    /// Arabic the name comes back `المغرب` and an assertion against the English word fails for a
    /// reason that has nothing to do with the title. What is under test here is that the *name*
    /// is in the title beside the countdown, and this asks the same question in either language.
    private var maghrib: String {
        LocalizationManager(
            settingsStore: InMemorySettingsStore(),
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService(),
            language: .english
        )
        .string(Prayer.maghrib.labelKey)
    }

    // MARK: The title the controller draws

    @Test func theFullRungCarriesTheNameTheSymbolAndTheTime() {
        let viewModel = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16))
        let title = viewModel.statusTitle(rung: .full)

        #expect(title.symbol == Prayer.maghrib.symbol)
        #expect(title.text.contains(maghrib))
        #expect(title.text.contains("2:00"))
    }

    @Test func droppingTheNameKeepsTheSymbolAndTheCountdown() {
        let viewModel = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16))
        let title = viewModel.statusTitle(rung: .symbolAndTime)

        #expect(title.symbol == Prayer.maghrib.symbol)
        #expect(!title.text.contains("Maghrib"))
        #expect(title.text.contains("2:00"))
    }

    @Test func theTimeOnlyRungHasNoSymbol() {
        let viewModel = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16))
        let title = viewModel.statusTitle(rung: .timeOnly)

        #expect(title.symbol == nil)
        #expect(title.text.contains("2:00"))
    }

    @Test func theSymbolOnlyRungDrawsNoText() {
        let viewModel = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16))
        let title = viewModel.statusTitle(rung: .symbolOnly)

        #expect(title.symbol == Prayer.maghrib.symbol)
        #expect(title.text.isEmpty)
    }

    /// Whatever the rung drops, the tooltip keeps — which is what makes dropping it cost nothing.
    /// The tooltip carries the *full* countdown, seconds included, because a reader who has gone
    /// to the trouble of hovering is looking at it.
    @Test func theTooltipIsWholeAtEveryRung() {
        let viewModel = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16))

        for rung in [MenuBarStatusRung.full, .symbolAndTime, .timeOnly, .symbolOnly] {
            let title = viewModel.statusTitle(rung: rung)

            #expect(title.tooltip.contains(maghrib), "at \(rung)")
            #expect(title.tooltip.contains("2:00:00"), "at \(rung)")
        }
    }

    /// With no position there is no countdown, so the item falls to its symbol and says why on
    /// hover. An item drawn as nothing at all would look like an app that had crashed.
    @Test func withNoPositionTheItemIsASymbolAndAnExplanation() {
        let viewModel = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16), located: false)
        let title = viewModel.statusTitle(rung: .full)

        #expect(title.symbol == "location.slash")
        #expect(title.text.isEmpty)
        #expect(!title.tooltip.isEmpty)
    }

    /// The slot is re-measured from the digits in use, not fixed at the Western width — which is
    /// the design's reason for measuring it at all.
    @Test func theSlotFollowsTheDigitSystem() {
        let western = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16), digits: .latin)
        let arabic = makeViewModel(at: PrayerTimeFixtures.instant(today, hour: 16), digits: .arabicIndic)

        #expect(western.statusSlotLength == arabic.statusSlotLength)
        #expect(western.statusSlotLength == 5)
    }
}
