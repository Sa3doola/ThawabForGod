//
//  ReminderPresentation.swift
//  ThawabForGod
//

import Foundation

/// The kinds of reminder this app delivers, as the notification system knows them.
///
/// A `UNNotificationCategory` identifier is what tells iOS which content extension to hand a
/// delivered notification to, so this enum is the contract between the app that schedules and the
/// extension that draws. One case today; the point of it being an enum is the ones coming after —
/// an adhkar reminder should be a case here and a branch in `ReminderCardView`, not a second
/// extension with a second copy of the card.
///
/// In `Shared/` rather than `Core/Notifications/` for the reason `NextPrayerTimeline` is: it is
/// read by a second process, and being compiled into the app target is what lets the app's own
/// suite test it.
nonisolated enum ReminderCategory: String, CaseIterable, Sendable {
    case prayer

    /// Namespaced, and **written into the content extension's `Info.plist` by hand** under
    /// `UNNotificationExtensionCategory`. A plist cannot read a Swift constant, so the two are
    /// kept in step by this comment and by `ReminderCategoryTests`, which asserts the string.
    var identifier: String { "noor.reminder.\(rawValue)" }

    init?(identifier: String) {
        guard let match = Self.allCases.first(where: { $0.identifier == identifier }) else {
            return nil
        }

        self = match
    }
}

/// Everything a delivered notification's custom view needs, carried in its `userInfo`.
///
/// **What is *not* here is as deliberate as what is.** There is no formatted time and no prayer
/// name — only the raw `Date` and the `Prayer` case. The card formats them itself, live, out of
/// the shared settings, so a reader who switches to Arabic-Indic digits sees them on the very next
/// notification rather than on the first one scheduled after the switch. Notification *text* is
/// baked in when a reminder is scheduled — that is a property of `UNMutableNotificationContent`
/// and the reason `RootView`'s refresh key carries the language — but nothing drawn by the
/// extension has to be.
///
/// `body` is the exception, and knowingly: it is the same sentence the collapsed banner shows, and
/// the card repeating it is what makes the expanded view a continuation of the banner rather than
/// a different notification. It comes along already localized.
nonisolated struct ReminderPresentation: Equatable, Sendable {

    /// What the reminder is about. The extension switches on this to pick a card.
    enum Subject: Equatable, Sendable {
        case prayer(Prayer)
    }

    let subject: Subject

    /// The instant the reminder is *for* — a prayer's time, not necessarily the moment it fires.
    let date: Date

    /// The localized sentence, as scheduled.
    let body: String

    init(subject: Subject, date: Date, body: String) {
        self.subject = subject
        self.date = date
        self.body = body
    }

    var category: ReminderCategory {
        switch subject {
        case .prayer: .prayer
        }
    }

    // MARK: userInfo

    private enum Key {
        static let category = "noor.reminder.category"
        static let prayer = "noor.reminder.prayer"
        static let date = "noor.reminder.date"
        static let body = "noor.reminder.body"
    }

    /// Plist types only — `String` and `Date`. `UNMutableNotificationContent.userInfo` is
    /// serialized by the system, and a value it cannot encode is dropped rather than reported.
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            Key.category: category.rawValue,
            Key.date: date,
            Key.body: body
        ]

        switch subject {
        case .prayer(let prayer):
            info[Key.prayer] = prayer.rawValue
        }

        return info
    }

    /// Reads a payload back, or fails.
    ///
    /// **`nil` rather than a default in every branch.** iOS keeps delivered notifications across
    /// app updates, so a card can be opened on a payload written by a build that no longer exists
    /// — the same promise `DeepLink` makes about cached shortcut items. Falling back to some
    /// prayer would draw a gloss of one prayer under another's name, which is worse than the
    /// system's own default layout.
    init?(userInfo: [AnyHashable: Any]) {
        guard let rawCategory = userInfo[Key.category] as? String,
              let category = ReminderCategory(rawValue: rawCategory),
              let date = userInfo[Key.date] as? Date,
              let body = userInfo[Key.body] as? String else {
            return nil
        }

        switch category {
        case .prayer:
            guard let rawPrayer = userInfo[Key.prayer] as? String,
                  let prayer = Prayer(rawValue: rawPrayer) else {
                return nil
            }

            subject = .prayer(prayer)
        }

        self.date = date
        self.body = body
    }
}
