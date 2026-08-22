//
//  SettingsViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftUI // LayoutDirection; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

/// What these check, mostly, is that nothing is *stored* on a view model. Each assertion follows
/// a setting from the screen it is changed on, through the manager that owns it, and on into the
/// store — because a copy living on a view model would pass a naive "did the property change"
/// test and still leave the rest of the app on the old value.
///
/// One suite for the six screens rather than six suites, because they share the whole of their
/// scaffolding: the same store, the same managers, wired the way the composition root wires them.
@MainActor
struct SettingsScreensTests {

    private struct Context {
        let screens: SettingsScreenModels
        let store: InMemorySettingsStore
        let theme: ThemeManager
        let localization: LocalizationManager
        let calculation: CalculationSettings
        let reminders: ReminderPreferences
        let notifications: MockNotificationService
        let tips: SpyTipsService
    }

    /// Noon on a fixed day. The sample time is placed at 17:05 relative to whatever this is, in
    /// the machine's own zone, so the clock assertions hold wherever the suite runs.
    /// `nonisolated` so the `@Sendable` clock closure below can read it: the suite is
    /// `@MainActor`, and a main-actor-isolated static crossing into that closure is an error
    /// under the Swift 6 language mode.
    private nonisolated static let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    /// - Parameter language: injected rather than read from the test host's bundle, because the
    ///   process language is exactly what these tests need to vary and cannot otherwise.
    private func makeContext(language: AppLanguage = .english) -> Context {
        let store = InMemorySettingsStore()
        let theme = ThemeManager(settingsStore: store)
        let localization = LocalizationManager(
            settingsStore: store,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService(),
            language: language
        )
        let calculation = CalculationSettings(config: .default, settingsStore: store)
        let reminders = ReminderPreferences(settingsStore: store)
        let notifications = MockNotificationService(status: .authorized)
        let tips = SpyTipsService()

        let screens = SettingsScreenModels(
            homeCustomization: HomeCustomizationViewModel(
                getLayout: GetHomeLayoutUseCase(
                    repository: HomeLayoutRepository(settingsStore: store)
                ),
                updateLayout: UpdateHomeLayoutUseCase(
                    repository: HomeLayoutRepository(settingsStore: store)
                ),
                resetLayout: ResetHomeLayoutUseCase(
                    repository: HomeLayoutRepository(settingsStore: store)
                )
            ),
            appearance: AppearanceSettingsViewModel(theme: theme),
            languageAndFormat: LanguageFormatSettingsViewModel(
                localization: localization,
                now: { Self.fixedNow }
            ),
            prayerCalculation: PrayerCalculationSettingsViewModel(calculation: calculation),
            reminders: RemindersSettingsViewModel(
                reminders: reminders,
                notifications: notifications
            ),
            tips: TipsSettingsViewModel(resetTips: ResetTipsUseCase(tips: tips)),
            about: AboutViewModel()
        )

        return Context(
            screens: screens,
            store: store,
            theme: theme,
            localization: localization,
            calculation: calculation,
            reminders: reminders,
            notifications: notifications,
            tips: tips
        )
    }

    // MARK: Appearance

    @Test func settingTheAccentDrivesTheThemeAndPersists() {
        let context = makeContext()

        context.screens.appearance.accent = .sapphire

        #expect(context.theme.accent == .sapphire)
        #expect(context.theme.theme.accent == AppColor.accent(.sapphire))
        #expect(context.store.string(for: .accentPalette) == AccentPalette.sapphire.rawValue)
    }

    @Test func settingTheAppearanceDrivesTheThemeAndPersists() {
        let context = makeContext()

        context.screens.appearance.appearance = .dark

        #expect(context.theme.appearance == .dark)
        #expect(context.store.string(for: .appearance) == AppearanceOverride.dark.rawValue)
    }

    /// The other direction. The properties are windows onto the managers, so a change made
    /// anywhere else has to show through — otherwise the screen could display a stale value.
    @Test func aChangeMadeElsewhereShowsThrough() {
        let context = makeContext()

        context.theme.select(accent: .rose)
        context.localization.select(numberSystem: .arabicIndic)
        context.calculation.select(method: .qatar)

        #expect(context.screens.appearance.accent == .rose)
        #expect(context.screens.languageAndFormat.numberSystem == .arabicIndic)
        #expect(context.screens.prayerCalculation.method == .qatar)
    }

    // MARK: Language and format

    /// The language is the system's, not the app's: the row reports what the process is running
    /// in and sends the user to the Settings app to change it.
    ///
    /// That it is never *persisted* is not asserted here, because it can no longer be expressed
    /// — `SettingsKey` has no `language` case, so a write would not compile. The compiler is a
    /// better guard than a test for that one, and it is the rule the whole change exists to
    /// keep: a stored language would outrank the system's choice forever.
    @Test func theLanguageIsReportedFromTheProcessRatherThanStored() {
        #expect(makeContext(language: .arabic).screens.languageAndFormat.language == .arabic)
        #expect(makeContext(language: .english).screens.languageAndFormat.language == .english)
    }

    @Test func settingTheDigitsDrivesLocalizationAndPersists() {
        let context = makeContext()

        context.screens.languageAndFormat.numberSystem = .arabicIndic

        #expect(context.localization.numberSystem == .arabicIndic)
        #expect(context.store.string(for: .numberSystem) == NumberSystem.arabicIndic.rawValue)
    }

    @Test func settingTheClockFormatDrivesLocalizationAndPersists() {
        let context = makeContext()

        context.screens.languageAndFormat.clockFormat = .twentyFourHour

        #expect(context.localization.clockFormat == .twentyFourHour)
        #expect(context.store.string(for: .clockFormat) == ClockFormat.twentyFourHour.rawValue)
    }

    // MARK: Live samples

    /// The sample is the only preview of a digit choice the user gets before it is applied to
    /// every number in the app, so it has to be formatted the same way those numbers are.
    @Test func theDigitsSampleFollowsTheChoice() {
        let context = makeContext()

        context.screens.languageAndFormat.numberSystem = .latin
        #expect(context.screens.languageAndFormat.digitsSample == "123")

        context.screens.languageAndFormat.numberSystem = .arabicIndic
        #expect(context.screens.languageAndFormat.digitsSample == "١٢٣")
    }

    @Test func theClockSampleFollowsTheChoice() {
        let context = makeContext()
        context.screens.languageAndFormat.numberSystem = .latin

        context.screens.languageAndFormat.clockFormat = .twentyFourHour
        #expect(context.screens.languageAndFormat.clockSample.contains("17"))

        context.screens.languageAndFormat.clockFormat = .twelveHour
        #expect(context.screens.languageAndFormat.clockSample.contains("5"))
        #expect(!context.screens.languageAndFormat.clockSample.contains("17"))
    }

    // MARK: Prayer calculation

    @Test func settingTheMethodDrivesTheSharedCalculationSettings() {
        let context = makeContext()

        context.screens.prayerCalculation.method = .northAmerica

        #expect(context.calculation.config.method == .northAmerica)
        #expect(context.store.string(for: .calculationMethod) == PrayerCalculationMethod.northAmerica.rawValue)
    }

    @Test func settingTheMadhabDrivesTheSharedCalculationSettings() {
        let context = makeContext()

        context.screens.prayerCalculation.madhab = .hanafi

        #expect(context.calculation.config.madhab == .hanafi)
        #expect(context.store.string(for: .asrMadhab) == AsrMadhab.hanafi.rawValue)
    }

    /// The whole point of the slice, in one test: a method chosen on this screen is the config
    /// Home's next recompute asks with. The view supplies only the `onChange` that calls
    /// `refresh()`; everything below it is here.
    @Test func changingTheMethodReachesThePrayerTimeCalculation() {
        let context = makeContext()
        let day = PrayerTimeFixtures.day(2026, 6, 15)
        let repository = RecordingPrayerTimeRepository(schedules: [day: PrayerTimeFixtures.schedule(on: day)])
        let home = HomeViewModel(
            useCase: GetPrayerScheduleUseCase(repository: repository, calendar: PrayerTimeFixtures.calendar),
            getLayout: HomeLayoutFixtures.getLayout(),
            coordinates: .makkah,
            hijriDates: StubHijriDateService(),
            calculation: context.calculation,
            tips: SpyHomeTipReporter(),
            clock: TestClock(PrayerTimeFixtures.instant(day, hour: 13))
        )

        context.screens.prayerCalculation.method = .singapore
        context.screens.prayerCalculation.madhab = .hanafi
        home.refresh()

        #expect(home.config == CalculationConfig(method: .singapore, madhab: .hanafi))
        #expect(repository.requestedConfigs.last == CalculationConfig(method: .singapore, madhab: .hanafi))
    }

    // MARK: Reminders

    /// Sunrise has no toggle because it starts no prayer — the screen must offer five switches,
    /// not six.
    @Test func onlyTheObligatoryPrayersCanBeReminded() {
        let context = makeContext()

        #expect(context.screens.reminders.remindablePrayers == [.fajr, .dhuhr, .asr, .maghrib, .isha])
    }

    /// Every reminder is on before anyone has opened this screen — and nothing has been written
    /// to say so, because a default that gets persisted stops being a default.
    @Test func remindersStartOnWithoutBeingWritten() {
        let context = makeContext()

        #expect(
            context.screens.reminders.remindablePrayers
                .allSatisfy(context.screens.reminders.isEnabled)
        )
        #expect(SettingsKey.allCases.allSatisfy { context.store.bool(for: $0) == nil })
    }

    @Test func switchingAReminderOffDrivesThePreferencesAndPersists() {
        let context = makeContext()

        context.screens.reminders.setEnabled(false, for: .fajr)

        #expect(context.screens.reminders.isEnabled(.fajr) == false)
        #expect(context.reminders.enabledPrayers.contains(.fajr) == false)
        #expect(context.store.bool(for: .reminderFajr) == false)
        // The others are untouched, and still unwritten.
        #expect(context.screens.reminders.isEnabled(.dhuhr))
        #expect(context.store.bool(for: .reminderDhuhr) == nil)
    }

    @Test func switchingAReminderBackOnPersistsThatToo() {
        let context = makeContext()

        context.screens.reminders.setEnabled(false, for: .isha)
        context.screens.reminders.setEnabled(true, for: .isha)

        #expect(context.screens.reminders.isEnabled(.isha))
        #expect(context.store.bool(for: .reminderIsha) == true)
    }

    /// The status starts unknown rather than assumed: a screen that guessed "allowed" would show
    /// live-looking switches to someone iOS is dropping every notification for.
    @Test func theNotificationStatusIsUnknownUntilAsked() async {
        let context = makeContext()
        #expect(context.screens.reminders.notificationsAllowed == nil)

        await context.screens.reminders.loadNotificationStatus()

        #expect(context.screens.reminders.notificationsAllowed == true)
    }

    @Test func arefusedPermissionIsReportedAsSuch() async {
        let context = makeContext()
        context.notifications.status = .denied

        await context.screens.reminders.loadNotificationStatus()

        #expect(context.screens.reminders.notificationsAllowed == false)
    }

    // MARK: Tips

    @Test func resettingTipsCallsThroughToTheService() {
        let context = makeContext()

        context.screens.tips.resetTipsTapped()

        #expect(context.tips.resetCount == 1)
        // The flag the footer reads. It is what tells the user the tips come back next launch
        // rather than now — see `ResetTipsUseCase`.
        #expect(context.screens.tips.hasResetTips)
    }

    @Test func tipsHaveNotBeenResetToBeginWith() {
        let context = makeContext()

        #expect(context.screens.tips.hasResetTips == false)
        #expect(context.tips.resetCount == 0)
    }

    // MARK: About

    /// Asserted on the shape rather than on a version, which would fail on the next bump.
    @Test func theVersionReadsAsAVersionAndABuild() {
        let context = makeContext()

        #expect(context.screens.about.versionText.contains(" ("))
        #expect(context.screens.about.versionText.hasSuffix(")"))
    }

    /// The attribution list is the plan's in-app requirement, so its shape is worth pinning:
    /// every entry needs a licence line, and every one that has an upstream needs a link.
    @Test func everySourceCarriesAnAttributionAndALicence() {
        let context = makeContext()
        let l10n = context.localization

        #expect(!context.screens.about.sources.isEmpty)

        for source in context.screens.about.sources {
            #expect(l10n.string(source.titleKey) != source.titleKey.rawValue)
            #expect(l10n.string(source.attributionKey) != source.attributionKey.rawValue)
            #expect(l10n.string(source.licenceKey) != source.licenceKey.rawValue)
        }
    }

    /// Every data set the corpus README says is short of a check carries a warning on screen, and
    /// no others do. If one is ever verified, its note is removed and this test is the reminder to
    /// update the list rather than the screen.
    ///
    /// They are not all short of the *same* check. The adhkar and the divine names are the two the
    /// README says must not ship as verified in V1 at all; the hadith are in the tafsir's position
    /// instead — a fixed classical text that independent transcriptions agree on, which nobody on
    /// this project has read against a printed edition. Both are worth saying, and both are said in
    /// the source's own note rather than sorted into tiers here.
    @Test func theUnverifiedContentIsMarkedAsSuch() {
        let context = makeContext()
        let noted = context.screens.about.sources.filter { $0.noteKey != nil }.map(\.id)

        #expect(noted.sorted() == ["adhkar", "hadith", "names"])
    }

    // MARK: Restoring the calculation defaults

    @Test func thereIsNothingToRestoreUntilSomethingIsChanged() {
        let context = makeContext()

        #expect(context.screens.prayerCalculation.hasChoices == false)

        context.screens.prayerCalculation.method = .karachi

        #expect(context.screens.prayerCalculation.hasChoices)
    }

    /// The reset clears the keys rather than writing today's defaults into them, so "never
    /// opinionated" stays distinguishable from "chose what the default happens to be" — the
    /// standing rule for every preference in this app.
    @Test func restoringDefaultsClearsTheKeysRatherThanStoringThem() {
        let context = makeContext()

        context.screens.prayerCalculation.method = .karachi
        context.screens.prayerCalculation.madhab = .hanafi
        #expect(context.store.string(for: .calculationMethod) != nil)

        context.screens.prayerCalculation.reset()

        #expect(context.screens.prayerCalculation.method == CalculationConfig.default.method)
        #expect(context.screens.prayerCalculation.madhab == CalculationConfig.default.madhab)
        #expect(context.store.string(for: .calculationMethod) == nil)
        #expect(context.store.string(for: .asrMadhab) == nil)
    }

    /// The shared object, not a copy: Home computes from the same `CalculationSettings`, so a
    /// reset here has to reach it too.
    @Test func restoringDefaultsReachesTheSharedCalculationSettings() {
        let context = makeContext()

        context.screens.prayerCalculation.method = .tehran
        #expect(context.calculation.config.method == .tehran)

        context.screens.prayerCalculation.reset()

        #expect(context.calculation.config == .default)
    }
}

/// The root list itself: seven rows, and one screen that is not among them.
struct SettingsRouteTests {

    @Test func theRootListsEverythingExceptTheSourcesScreen() {
        #expect(SettingsRoute.root.contains(.sources) == false)
        #expect(SettingsRoute.root.count == SettingsRoute.allCases.count - 1)
    }

    @Test func homeCustomizationComesFirst() {
        #expect(SettingsRoute.root.first == .homeCustomization)
    }

    /// A row with no title is a row nobody can read, and a symbol name is a string the compiler
    /// cannot check — so this is the tripwire for both.
    @Test func everyRouteHasATitleAndASymbol() {
        for route in SettingsRoute.allCases {
            #expect(route.symbol.isEmpty == false)
            #expect(route.titleKey.rawValue.isEmpty == false)
        }
    }
}
