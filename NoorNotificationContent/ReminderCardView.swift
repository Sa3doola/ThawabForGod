//
//  ReminderCardView.swift
//  NoorNotificationContent
//

import Observation
import SwiftUI

/// What the card is drawing, set by the view controller when the notification arrives.
///
/// `@Observable` rather than a value passed at construction, because the hosting controller is
/// installed in `viewDidLoad` and the payload lands afterwards — see `didReceive(_:)`.
@Observable
final class ReminderCardModel {
    /// The decoded payload, or `nil` for one this build cannot read.
    var presentation: ReminderPresentation?

    /// The notification's own strings, already localized when it was scheduled. The fallback for
    /// the case above, and never worse than what the system would have shown.
    var title: String = ""
    var body: String = ""
}

/// A reminder, drawn as the app would draw it.
///
/// The prayer's own light behind it, its symbol, its name, its time, and the sentence. The same
/// `DayRampBackground` the Home card, the widget and the banner thumbnail all use, so a reminder
/// looks like a piece of Noor rather than like a notification from somewhere else.
///
/// **The time is formatted here, live.** Notification *text* is baked in when a reminder is
/// scheduled — that is a property of `UNMutableNotificationContent`, and it is why a language
/// change has to trigger a refresh — but this card is drawn at the moment the reader pulls it
/// down, so it reads the digits and the hour cycle out of the App Group and formats the raw
/// `Date` the payload carries. A reader who switches to Arabic-Indic numerals sees them on the
/// very next notification rather than on the first one scheduled after the switch.
///
/// Through `LocaleTimeFormattingService` and `Theme`, the same types the app and the widget use,
/// so a screen, a Home Screen and a banner cannot disagree about what a time looks like.
struct ReminderCardView: View {

    @Bindable var model: ReminderCardModel

    /// Read once. An extension is constructed, shown and torn down inside a single interaction,
    /// so there is nothing here to observe a change of.
    private let style = ReminderCardStyle()

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            if let prayer {
                Image(systemName: prayer.symbol)
                    .appFont(.largeTitle)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: AppSpacing.xxxl)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)

                if let time {
                    Text(time)
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                }

                Text(message)
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let prayer {
                DayRampBackground(stop: DayRamp.stop(for: prayer))
            } else {
                theme.background
            }
        }
        .environment(\.layoutDirection, style.isRightToLeft ? .rightToLeft : .leftToRight)
        // The three lines read as one thought, and VoiceOver should announce them as one.
        .accessibilityElement(children: .combine)
    }

    // MARK: What there is to draw

    private var prayer: Prayer? {
        switch model.presentation?.subject {
        case .prayer(let prayer): prayer
        case nil: nil
        }
    }

    /// The notification's own title. Not re-derived from the prayer: it was localized when the
    /// reminder was scheduled, and re-resolving it here would be a second answer to a question
    /// that already has one.
    private var title: String { model.title }

    /// `message` rather than `body`, which `View` already owns.
    private var message: String { model.presentation?.body ?? model.body }

    private var time: String? {
        model.presentation.map { style.time($0.date) }
    }

    /// Inverted, because the ramp is what is behind it — see `Theme.onDayRamp`. Without a payload
    /// there is no ramp, so the plain palette is the right one.
    private var theme: Theme {
        prayer == nil ? style.theme : style.theme.onDayRamp
    }
}

/// The presentation choices, out of the App Group.
///
/// The same three the widget's `NextPrayerSnapshot.Style` carries, read the same way and falling
/// back the same way: an unset or unrecognised value means the reader has never chosen, and the
/// device decides. The language is the process's, which in an extension is its own bundle — and
/// correct, because both bundles carry the same string catalog and iOS gives them the same
/// preferred localization.
private struct ReminderCardStyle {
    private let times = LocaleTimeFormattingService()
    private let language = AppLanguage.current()
    private let numberSystem: NumberSystem
    private let clockFormat: ClockFormat
    let theme: Theme

    init() {
        let store = UserDefaultsSettingsStore(defaults: SharedDefaults.store)

        numberSystem = store.string(for: .numberSystem)
            .flatMap(NumberSystem.init(rawValue:)) ?? .preferred(for: language)
        clockFormat = store.string(for: .clockFormat)
            .flatMap(ClockFormat.init(rawValue:)) ?? .fallback
        theme = Theme(
            accent: store.string(for: .accentPalette)
                .flatMap(AccentPalette.init(rawValue:)) ?? .fallback
        )
    }

    var isRightToLeft: Bool { language.isRightToLeft }

    func time(_ date: Date) -> String {
        times.timeString(from: date, language: language, system: numberSystem, clock: clockFormat)
    }
}

#if DEBUG
#Preview("Maghrib") {
    let model = ReminderCardModel()
    model.presentation = ReminderPresentation(
        subject: .prayer(.maghrib),
        date: Date(),
        body: "It's time to pray."
    )
    model.title = "Maghrib"
    model.body = "It's time to pray."

    return ReminderCardView(model: model)
}

/// The fallback: a payload written by a build that no longer exists. The card has to stay
/// readable, which means the notification's own strings and no ramp.
#Preview("Unreadable payload") {
    let model = ReminderCardModel()
    model.title = "Maghrib"
    model.body = "It's time to pray."

    return ReminderCardView(model: model)
}
#endif
