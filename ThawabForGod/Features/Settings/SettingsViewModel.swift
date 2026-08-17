//
//  SettingsViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the Settings screen.
///
/// **It stores almost nothing.** Every preference on this screen already has an owner —
/// `ThemeManager` holds the accent and appearance, `LocalizationManager` the language, digits and
/// clock, `CalculationSettings` the prayer-calculation choices — and each of those already
/// persists through `SettingsStore`. So this type forwards rather than mirrors: a second copy of
/// the accent living here would be a second source of truth, and the two would drift the first
/// time anything else changed one.
///
/// That is also why the properties below are computed with setters rather than stored. Reading one
/// inside a view registers an observation dependency on the *owner*, so `$viewModel.accent` in a
/// picker both writes through to the manager and re-renders when anything else changes it.
///
/// The one piece of real state is `hasResetTips`, which belongs to this screen and nowhere else.
@Observable
@MainActor
final class SettingsViewModel {

    /// Whether the tips reset has been asked for in this session.
    ///
    /// Drives a confirmation, and the confirmation matters: TipKit does not bring dismissed tips
    /// back until the next launch, so a row that silently did nothing visible would read as
    /// broken. See `ResetTipsUseCase`.
    private(set) var hasResetTips = false

    /// Whether the system will actually deliver reminders, or `nil` until it has been asked.
    ///
    /// The one piece of genuinely asynchronous state on this screen, and worth having: without
    /// it the reminder toggles would look live while iOS silently dropped every notification,
    /// which is the sort of thing a user blames the app for.
    private(set) var notificationsAllowed: Bool?

    @ObservationIgnored private let theme: ThemeManager
    @ObservationIgnored private let localization: LocalizationManager
    @ObservationIgnored private let calculation: CalculationSettings
    @ObservationIgnored private let reminders: ReminderPreferences
    @ObservationIgnored private let notifications: any NotificationService
    @ObservationIgnored private let resetTips: ResetTipsUseCase
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - bundle: where the version is read from. Injected so a test does not assert against
    ///     whatever the test host happens to be versioned as.
    ///   - now: the clock, used only to place the sample time. Injected for the same reason.
    init(
        theme: ThemeManager,
        localization: LocalizationManager,
        calculation: CalculationSettings,
        reminders: ReminderPreferences,
        notifications: any NotificationService,
        resetTips: ResetTipsUseCase,
        bundle: Bundle = .main,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.theme = theme
        self.localization = localization
        self.calculation = calculation
        self.reminders = reminders
        self.notifications = notifications
        self.resetTips = resetTips
        self.bundle = bundle
        self.now = now
    }

    // MARK: Appearance

    var accent: AccentPalette {
        get { theme.accent }
        set { theme.select(accent: newValue) }
    }

    var appearance: AppearanceOverride {
        get { theme.appearance }
        set { theme.select(appearance: newValue) }
    }

    // MARK: Language and format

    /// Read-only, unlike everything else on this screen: the language is the system's to set, in
    /// the app's own page in the Settings app, and picking there relaunches the process. The row
    /// reports it and offers the way there — see `FormatSettingsSection`.
    var language: AppLanguage { localization.language }

    var numberSystem: NumberSystem {
        get { localization.numberSystem }
        set { localization.select(numberSystem: newValue) }
    }

    var clockFormat: ClockFormat {
        get { localization.clockFormat }
        set { localization.select(clockFormat: newValue) }
    }

    // MARK: Prayer calculation

    var method: PrayerCalculationMethod {
        get { calculation.config.method }
        set { calculation.select(method: newValue) }
    }

    var madhab: AsrMadhab {
        get { calculation.config.madhab }
        set { calculation.select(madhab: newValue) }
    }

    // MARK: Reminders

    /// The five prayers a reminder can be set for. Sunrise is not among them — it ends Fajr's
    /// window rather than starting a prayer.
    var remindablePrayers: [Prayer] { Prayer.remindable }

    func isReminderEnabled(_ prayer: Prayer) -> Bool {
        reminders.isEnabled(prayer)
    }

    func setReminder(_ isEnabled: Bool, for prayer: Prayer) {
        reminders.setEnabled(isEnabled, for: prayer)
    }

    /// Asks the system whether reminders can be delivered at all.
    ///
    /// Driven from the screen's `.task`, so it re-runs on each appearance — permission can be
    /// revoked in the Settings app while this app is in the background, and the answer read at
    /// construction would be stale by the time anybody looked at it.
    func loadNotificationStatus() async {
        notificationsAllowed = await notifications.authorizationStatus() == .authorized
    }

    // MARK: Live samples

    /// A number drawn in the selected digits, so the choice can be seen before it is made
    /// everywhere else. Through `LocalizationManager`, never interpolation.
    var digitsSample: String {
        localization.string(123, grouped: false)
    }

    /// A clock time in the selected form. Late afternoon on purpose — it is the half of the day
    /// where 12- and 24-hour form differ, so the sample shows something when it changes.
    var clockSample: String {
        localization.timeString(sampleTime)
    }

    /// 17:05 today, in the user's time zone.
    ///
    /// Its own Gregorian calendar rather than `Calendar.current`, for the reason `PrayerTimeEngine`
    /// documents: on a device set to the Islamic calendar, `current` would answer in Hijri
    /// components and place the sample in the wrong year.
    private var sampleTime: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent

        let instant = now()
        return calendar.date(bySettingHour: 17, minute: 5, second: 0, of: instant) ?? instant
    }

    // MARK: Tips

    func resetTipsTapped() {
        resetTips()
        hasResetTips = true
    }

    // MARK: About

    /// The marketing version, with the build behind it — `1.0 (12)`.
    ///
    /// Not routed through the digit formatter: a version is an identifier rather than a quantity,
    /// and `١.٠ (١٢)` would not match what the App Store, a crash report or a bug reporter says.
    var versionText: String {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = bundle.infoDictionary?["CFBundleVersion"] as? String else {
            return version
        }
        return "\(version) (\(build))"
    }

    /// Every bundled data set and dependency, for the attribution screen.
    var sources: [AttributionSource] { AttributionSource.all }
}
