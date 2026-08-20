//
//  LanguageFormatSettingsViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Language, digits and clock — three choices that are deliberately separate.
///
/// Separate because they answer different questions: an Arabic reader may prefer Latin digits, and
/// a reader in either language may want 24-hour times. A single `Locale` cannot express those
/// combinations, which is why `LocalizationManager` exists at all.
///
/// **The language is read-only here**, and that is a decision rather than a gap. It belongs to the
/// system: the bundle ships both localizations, so iOS gives the app a Language row of its own in
/// its Settings page, and picking there relaunches the process. An in-app switcher was built once
/// and removed — `Form` and `List` fix their right-to-left mirroring when their backing view is
/// created, so flipping `layoutDirection` under a live one renders every glyph backwards. See
/// `LocalizationManager` for the whole account.
@Observable
@MainActor
final class LanguageFormatSettingsViewModel {
    @ObservationIgnored private let localization: LocalizationManager
    @ObservationIgnored private let now: @Sendable () -> Date

    /// - Parameter now: the clock, used only to place the sample time. Injected so a test does
    ///   not assert against whatever moment it happens to run at.
    init(localization: LocalizationManager, now: @escaping @Sendable () -> Date = Date.init) {
        self.localization = localization
        self.now = now
    }

    var language: AppLanguage { localization.language }

    var numberSystem: NumberSystem {
        get { localization.numberSystem }
        set { localization.select(numberSystem: newValue) }
    }

    var clockFormat: ClockFormat {
        get { localization.clockFormat }
        set { localization.select(clockFormat: newValue) }
    }

    // MARK: Live samples

    /// A number in the selected digits, so the choice can be seen before it is made everywhere
    /// else. Through `LocalizationManager`, never interpolation.
    var digitsSample: String {
        localization.string(123, grouped: false)
    }

    /// A clock time in the selected form. Late afternoon on purpose — it is the half of the day
    /// where 12- and 24-hour form differ, so the sample shows something when it changes.
    var clockSample: String {
        localization.timeString(sampleTime)
    }

    /// 17:05 today, in the user's time zone. Its own Gregorian calendar, for the reason
    /// `PrayerTimeEngine` documents: on a device set to the Islamic calendar, `current` would
    /// answer in Hijri components and place the sample in the wrong year.
    private var sampleTime: Date {
        let instant = now()
        return Calendar.gregorianLocal
            .date(bySettingHour: 17, minute: 5, second: 0, of: instant) ?? instant
    }
}
