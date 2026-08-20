//
//  HomeSectionKind.swift
//  ThawabForGod
//

import Foundation

/// Everything Home can stack below its header, whether or not it is built yet.
///
/// The enum is the app's list of *possible* sections; `HomeLayout` decides which of them a
/// particular user sees and in what order. Cases are declared in the order a fresh install
/// shows them, which is what makes `HomeLayout.default` a plain map over `allCases` — and what
/// gives the forward-compatibility rule a canonical place to append a case nobody has stored
/// yet.
///
/// **Reserved cases ship now and light up later.** `ayahOfDay` and its neighbours exist here
/// before the features behind them do, so that adding one is a change to `isAvailable` rather
/// than a migration of everybody's stored layout. That is the whole reason the enum is longer
/// than the app.
nonisolated enum HomeSectionKind: String, CaseIterable, Codable, Sendable {
    /// The next-prayer card. Pinned — see `isPinned`.
    case nextPrayer
    case shortcuts
    case continueReading
    case lastActivity
    case prayerTracker
    case islamicCalendar
    case ayahOfDay
    case hadithOfDay
    case duaOfDay

    /// The one section the user does not get to move or hide.
    ///
    /// A constant rather than a scattering of `== .nextPrayer` checks, so the pin can be read
    /// off one line and `HomeLayout`'s invariants can talk about "the pinned section" without
    /// naming it.
    static let pinned: HomeSectionKind = .nextPrayer

    var isPinned: Bool { self == Self.pinned }

    /// Whether the feature behind this section exists yet.
    ///
    /// An unavailable kind is filtered out of the Home stack *and* out of the customization
    /// screen, so a user is never offered a switch that turns on nothing. Flipping one of these
    /// to `true` is the one-line change that ships a reserved section.
    var isAvailable: Bool {
        switch self {
        case .nextPrayer, .shortcuts, .continueReading, .lastActivity:
            true
        // Built in its own slice; the toggle here is what reveals it.
        case .prayerTracker:
            false
        // Phase 3 and beyond: there is no calendar screen, no verse-of-the-day corpus, and no
        // hadith yet.
        case .islamicCalendar, .ayahOfDay, .hadithOfDay, .duaOfDay:
            false
        }
    }

    /// The section's name, for the customization screen — and for the heading a section draws
    /// above itself where it has one.
    var labelKey: L10nKey {
        switch self {
        case .nextPrayer: .homeSectionNextPrayer
        case .shortcuts: .homeSectionShortcuts
        case .continueReading: .homeSectionContinueReading
        case .lastActivity: .homeSectionLastActivity
        case .prayerTracker: .homeSectionPrayerTracker
        case .islamicCalendar: .homeSectionIslamicCalendar
        case .ayahOfDay: .homeSectionAyahOfDay
        case .hadithOfDay: .homeSectionHadithOfDay
        case .duaOfDay: .homeSectionDuaOfDay
        }
    }

    /// The SF Symbol beside its row in the customization screen.
    var symbol: String {
        switch self {
        case .nextPrayer: "clock"
        case .shortcuts: "square.grid.2x2"
        case .continueReading: "book"
        case .lastActivity: "clock.arrow.circlepath"
        case .prayerTracker: "checkmark.circle"
        case .islamicCalendar: "calendar"
        case .ayahOfDay: "text.quote"
        case .hadithOfDay: "text.book.closed"
        case .duaOfDay: "hands.sparkles"
        }
    }

    /// Whether a fresh install shows this section — and, because unknown kinds are appended
    /// with this value, whether an existing user finds it switched on when it lands.
    ///
    /// Reserved kinds are hidden rather than visible so that shipping one does not silently
    /// rearrange a Home screen somebody had already settled on.
    var defaultVisibility: Bool {
        switch self {
        case .nextPrayer, .shortcuts, .continueReading, .lastActivity, .prayerTracker:
            true
        case .islamicCalendar, .ayahOfDay, .hadithOfDay, .duaOfDay:
            false
        }
    }
}
