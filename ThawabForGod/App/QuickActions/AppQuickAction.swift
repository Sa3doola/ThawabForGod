//
//  AppQuickAction.swift
//  ThawabForGod
//

import Foundation

/// What a long press on the app icon offers — and, on macOS, what the Dock menu lists.
///
/// The same shape as `HomeShortcut`, on purpose. That type already answers "a list of features
/// that has to stay cheap to add to, reorder, or take away", and answering it a second way here
/// would leave two conventions in one app. So: declaration order is display order,
/// `isAvailable` is the one switch that removes an entry, and everything a row needs to draw
/// itself hangs off the case.
///
/// **Adding one** is a case plus its four properties. **Hiding one** is either flipping
/// `isAvailable` to `false` — for a feature that has gone away — or moving it below the fourth
/// position, for one that is simply not important enough to spend a slot on. Nothing else in the
/// app has to change either way, which is the whole point of the type.
///
/// The link is a `DeepLink` rather than an `AppRoute` because a shortcut item outlives the
/// build that created it: iOS caches what it was given, so the reader can tap an action from
/// last week's install. It has to name a promise, not an implementation detail.
nonisolated enum AppQuickAction: String, CaseIterable, Sendable {
    case prayerTimes
    case qibla
    case adhkar
    case quran
    case tasbih
    case names
    case hadith

    /// iOS shows four and silently drops the rest.
    ///
    /// Named here so the truncation is a decision this app makes rather than one the system
    /// makes for it — the same argument `AppTab` records about the iPhone's five-tab limit,
    /// where the sixth section disappears behind a "More" tab nobody asked for.
    static let maximumVisible = 4

    /// Whether the feature behind this action exists and should be offered at all.
    ///
    /// Every case is available today. It stays here because the list is meant to outlive that:
    /// a feature withdrawn or not yet shipped is one `false`, and an action that would open
    /// nothing never reaches the Home Screen.
    var isAvailable: Bool { true }

    /// The actions actually offered, in order, capped at what the system will show.
    static var visible: [AppQuickAction] {
        Array(allCases.filter(\.isAvailable).prefix(maximumVisible))
    }

    /// Where tapping it goes.
    var link: DeepLink {
        switch self {
        case .prayerTimes: .prayerTimes
        case .qibla: .qibla
        // The list rather than a category: the reader who wants the morning adhkar at seven in
        // the evening should not have to back out of the wrong one.
        case .adhkar: .adhkar
        case .quran: .quran
        case .tasbih: .tasbih
        case .names: .names
        case .hadith: .hadith
        }
    }

    /// The label, resolved at registration time.
    ///
    /// Reused from the screens themselves — every one of these names stands alone already, so
    /// inventing a second set of strings for the Home Screen would be seven more keys saying the
    /// same words. `prayerTimes` borrows the day sheet's title, which is exactly where it lands.
    var titleKey: L10nKey {
        switch self {
        case .prayerTimes: .prayerTimesSheetTitle
        case .qibla: .qiblaTitle
        case .adhkar: .adhkarTitle
        case .quran: .quranTitle
        case .tasbih: .tasbihTitle
        case .names: .namesTitle
        case .hadith: .hadithTitle
        }
    }

    /// The SF Symbol beside the row. A plain string, so naming it costs no import — the same
    /// trade `Prayer.symbol`, `AppTab.symbol` and `HomeShortcut.symbol` all make.
    var symbol: String {
        switch self {
        case .prayerTimes: "clock"
        case .qibla: "location.north.line"
        case .adhkar: "hands.sparkles"
        case .quran: "book.closed"
        case .tasbih: "circle.hexagonpath"
        case .names: "sparkles"
        case .hadith: "text.book.closed"
        }
    }
}
