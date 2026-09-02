//
//  ReminderContentProviding.swift
//  ThawabForGod
//

import Foundation

/// The words a reminder shows, and the payload its custom view is drawn from.
///
/// Title, subtitle and body are the *collapsed banner* — the three fields iOS renders itself, and
/// the whole of what can be put there: a banner's layout is not customisable, so the only lever is
/// which of those three lines carries which fact, plus the attachment thumbnail
/// `ReminderArtworkProviding` supplies. `presentation` is the expanded view's, read back out of
/// `userInfo` by the content extension.
nonisolated struct ReminderContent: Equatable, Sendable {
    /// The bold first line. The prayer's name.
    let title: String

    /// The line beside it. The prayer's clock time — the fact a reader most often wants from a
    /// reminder they are looking at ten minutes late.
    let subtitle: String

    /// The sentence underneath.
    let body: String

    /// What the content extension redraws from.
    let presentation: ReminderPresentation

    var category: ReminderCategory { presentation.category }

    init(title: String, subtitle: String, body: String, presentation: ReminderPresentation) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.presentation = presentation
    }
}

/// Resolves a reminder into the text it carries.
///
/// A seam rather than a call to `LocalizationManager` inside the scheduler, for a reason worth
/// stating: notification text is baked in **when the reminder is scheduled**, not when it is
/// delivered. A pending reminder therefore keeps whatever language was in effect at its last
/// refresh, which is why a language change has to trigger a refresh like a method change does.
/// Naming the seam is what makes that dependency visible instead of buried.
///
/// That rule is why `presentation` carries a raw `Date` and a `Prayer` rather than the formatted
/// strings above them: the *banner* has to be baked, but the expanded card does not, and it is
/// drawn from the payload at the moment the reader pulls it down.
///
/// Nothing about the user goes in here — a prayer name, a time and a fixed sentence. A
/// notification is shown on a locked screen to whoever is holding the phone.
@MainActor
protocol ReminderContentProviding {
    func content(for reminder: PrayerReminder) -> ReminderContent
}
