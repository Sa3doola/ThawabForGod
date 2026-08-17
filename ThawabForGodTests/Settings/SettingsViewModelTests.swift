//
//  SettingsViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import SwiftUI // LayoutDirection; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

/// What these check, mostly, is that nothing is *stored* here. Each assertion follows a setting
/// from the view model through to the manager that owns it and on into the store, because a copy
/// living on the view model would pass a naive "did the property change" test and still leave the
/// rest of the app on the old value.
@MainActor
struct SettingsViewModelTests {

    private struct Context {
        let viewModel: SettingsViewModel
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

        let viewModel = SettingsViewModel(
            theme: theme,
            localization: localization,
            calculation: calculation,
            reminders: reminders,
            notifications: notifications,
            resetTips: ResetTipsUseCase(tips: tips),
            now: { Self.fixedNow }
        )

        return Context(
            viewModel: viewModel,
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

        context.viewModel.accent = .sapphire

        #expect(context.theme.accent == .sapphire)
        #expect(context.theme.theme.accent == AppColor.accent(.sapphire))
        #expect(context.store.string(for: .accentPalette) == AccentPalette.sapphire.rawValue)
    }

    @Test func settingTheAppearanceDrivesTheThemeAndPersists() {
        let context = makeContext()

        context.viewModel.appearance = .dark

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

        #expect(context.viewModel.accent == .rose)
        #expect(context.viewModel.numberSystem == .arabicIndic)
        #expect(context.viewModel.method == .qatar)
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
        #expect(makeContext(language: .arabic).viewModel.language == .arabic)
        #expect(makeContext(language: .english).viewModel.language == .english)
    }

    @Test func settingTheDigitsDrivesLocalizationAndPersists() {
        let context = makeContext()

        context.viewModel.numberSystem = .arabicIndic

        #expect(context.localization.numberSystem == .arabicIndic)
        #expect(context.store.string(for: .numberSystem) == NumberSystem.arabicIndic.rawValue)
    }

    @Test func settingTheClockFormatDrivesLocalizationAndPersists() {
        let context = makeContext()

        context.viewModel.clockFormat = .twentyFourHour

        #expect(context.localization.clockFormat == .twentyFourHour)
        #expect(context.store.string(for: .clockFormat) == ClockFormat.twentyFourHour.rawValue)
    }

    // MARK: Live samples

    /// The sample is the only preview of a digit choice the user gets before it is applied to
    /// every number in the app, so it has to be formatted the same way those numbers are.
    @Test func theDigitsSampleFollowsTheChoice() {
        let context = makeContext()

        context.viewModel.numberSystem = .latin
        #expect(context.viewModel.digitsSample == "123")

        context.viewModel.numberSystem = .arabicIndic
        #expect(context.viewModel.digitsSample == "١٢٣")
    }

    @Test func theClockSampleFollowsTheChoice() {
        let context = makeContext()
        context.viewModel.numberSystem = .latin

        context.viewModel.clockFormat = .twentyFourHour
        #expect(context.viewModel.clockSample.contains("17"))

        context.viewModel.clockFormat = .twelveHour
        #expect(context.viewModel.clockSample.contains("5"))
        #expect(!context.viewModel.clockSample.contains("17"))
    }

    // MARK: Prayer calculation

    @Test func settingTheMethodDrivesTheSharedCalculationSettings() {
        let context = makeContext()

        context.viewModel.method = .northAmerica

        #expect(context.calculation.config.method == .northAmerica)
        #expect(context.store.string(for: .calculationMethod) == PrayerCalculationMethod.northAmerica.rawValue)
    }

    @Test func settingTheMadhabDrivesTheSharedCalculationSettings() {
        let context = makeContext()

        context.viewModel.madhab = .hanafi

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
            coordinates: .makkah,
            hijriDates: StubHijriDateService(),
            calculation: context.calculation,
            tips: SpyHomeTipReporter(),
            now: { PrayerTimeFixtures.instant(day, hour: 13) }
        )

        context.viewModel.method = .singapore
        context.viewModel.madhab = .hanafi
        home.refresh()

        #expect(home.config == CalculationConfig(method: .singapore, madhab: .hanafi))
        #expect(repository.requestedConfigs.last == CalculationConfig(method: .singapore, madhab: .hanafi))
    }

    // MARK: Reminders

    /// Sunrise has no toggle because it starts no prayer — the screen must offer five switches,
    /// not six.
    @Test func onlyTheObligatoryPrayersCanBeReminded() {
        let context = makeContext()

        #expect(context.viewModel.remindablePrayers == [.fajr, .dhuhr, .asr, .maghrib, .isha])
    }

    /// Every reminder is on before anyone has opened this screen — and nothing has been written
    /// to say so, because a default that gets persisted stops being a default.
    @Test func remindersStartOnWithoutBeingWritten() {
        let context = makeContext()

        #expect(context.viewModel.remindablePrayers.allSatisfy(context.viewModel.isReminderEnabled))
        #expect(SettingsKey.allCases.allSatisfy { context.store.bool(for: $0) == nil })
    }

    @Test func switchingAReminderOffDrivesThePreferencesAndPersists() {
        let context = makeContext()

        context.viewModel.setReminder(false, for: .fajr)

        #expect(context.viewModel.isReminderEnabled(.fajr) == false)
        #expect(context.reminders.enabledPrayers.contains(.fajr) == false)
        #expect(context.store.bool(for: .reminderFajr) == false)
        // The others are untouched, and still unwritten.
        #expect(context.viewModel.isReminderEnabled(.dhuhr))
        #expect(context.store.bool(for: .reminderDhuhr) == nil)
    }

    @Test func switchingAReminderBackOnPersistsThatToo() {
        let context = makeContext()

        context.viewModel.setReminder(false, for: .isha)
        context.viewModel.setReminder(true, for: .isha)

        #expect(context.viewModel.isReminderEnabled(.isha))
        #expect(context.store.bool(for: .reminderIsha) == true)
    }

    /// The status starts unknown rather than assumed: a screen that guessed "allowed" would show
    /// live-looking switches to someone iOS is dropping every notification for.
    @Test func theNotificationStatusIsUnknownUntilAsked() async {
        let context = makeContext()
        #expect(context.viewModel.notificationsAllowed == nil)

        await context.viewModel.loadNotificationStatus()

        #expect(context.viewModel.notificationsAllowed == true)
    }

    @Test func arefusedPermissionIsReportedAsSuch() async {
        let context = makeContext()
        context.notifications.status = .denied

        await context.viewModel.loadNotificationStatus()

        #expect(context.viewModel.notificationsAllowed == false)
    }

    // MARK: Tips

    @Test func resettingTipsCallsThroughToTheService() {
        let context = makeContext()

        context.viewModel.resetTipsTapped()

        #expect(context.tips.resetCount == 1)
        // The flag the footer reads. It is what tells the user the tips come back next launch
        // rather than now — see `ResetTipsUseCase`.
        #expect(context.viewModel.hasResetTips)
    }

    @Test func tipsHaveNotBeenResetToBeginWith() {
        let context = makeContext()

        #expect(context.viewModel.hasResetTips == false)
        #expect(context.tips.resetCount == 0)
    }

    // MARK: About

    /// Asserted on the shape rather than on a version, which would fail on the next bump.
    @Test func theVersionReadsAsAVersionAndABuild() {
        let context = makeContext()

        #expect(context.viewModel.versionText.contains(" ("))
        #expect(context.viewModel.versionText.hasSuffix(")"))
    }

    /// The attribution list is the plan's in-app requirement, so its shape is worth pinning:
    /// every entry needs a licence line, and every one that has an upstream needs a link.
    @Test func everySourceCarriesAnAttributionAndALicence() {
        let context = makeContext()
        let l10n = context.localization

        #expect(!context.viewModel.sources.isEmpty)

        for source in context.viewModel.sources {
            #expect(l10n.string(source.titleKey) != source.titleKey.rawValue)
            #expect(l10n.string(source.attributionKey) != source.attributionKey.rawValue)
            #expect(l10n.string(source.licenceKey) != source.licenceKey.rawValue)
        }
    }

    /// The two data sets the corpus README says must not ship as verified are the two that carry
    /// a warning on screen. If one is ever verified, its note is removed and this test is the
    /// reminder to update the list rather than the screen.
    @Test func theUnverifiedContentIsMarkedAsSuch() {
        let context = makeContext()
        let noted = context.viewModel.sources.filter { $0.noteKey != nil }.map(\.id)

        #expect(noted.sorted() == ["adhkar", "names"])
    }
}
