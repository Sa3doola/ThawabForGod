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
///
/// A case can also be *withdrawn*, and one has been: `todayTimes` drew the day's six markers as a
/// card of their own until they moved back inside the hero. Nothing had to be migrated — rule 3
/// of `HomeLayout` drops a stored raw value that no longer maps to a case, and the layout either
/// side of it survives.
nonisolated enum HomeSectionKind: String, CaseIterable, Codable, Sendable {
    /// The next-prayer card — the countdown and the day's six markers under it. Pinned, see
    /// `isPinned`.
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
        case .nextPrayer, .shortcuts, .continueReading, .lastActivity, .prayerTracker,
             .islamicCalendar:
            true
        // Phase 3 and beyond: there is no verse-of-the-day corpus and no hadith of the day yet.
        case .ayahOfDay, .hadithOfDay, .duaOfDay:
            false
        }
    }

    /// Whether this section reads correctly at half the width of the stack.
    ///
    /// The middle breakpoint — a large phone in landscape, an iPad in a half-width Split View —
    /// is too narrow for the two-column board and too wide for a single column of cards each as
    /// long as a forearm. What fits there is a *pair*: two short cards side by side, with the
    /// long ones still spanning.
    ///
    /// So the question is asked of the section rather than answered by the layout, because only
    /// the section knows its own shape. The tracker is five tiles and the continue-reading card
    /// is one line and a progress bar: both are short and neither has anything that has to wrap.
    /// The shortcuts row is five circles that already fill the width, and recent activity is a
    /// list whose rows are sentences — halving either produces truncation, not density.
    ///
    /// The pinned section is absent on purpose: it spans at every width, for the reason
    /// `HomeView.stack(width:)` gives.
    var canPair: Bool {
        switch self {
        case .prayerTracker, .continueReading:
            true
        case .nextPrayer, .shortcuts, .lastActivity:
            false
        // The calendar card is a date, a moon and a line about what is next: it spans. The rest
        // are reserved — a verse and a hadith are passages, and a passage at half width is a
        // column of two words, so they will span when they land too.
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
    ///
    /// **This is not a migration, and the calendar card is the case that shows it.** Nothing is
    /// stored until a user edits Home, so a never-customized user is *derived* from this and finds
    /// the card on; a user who has customized has the card stored as hidden — written by a build
    /// where it did not exist — and keeps their Home as it was. It is in the customization list
    /// for them to switch on.
    var defaultVisibility: Bool {
        switch self {
        case .nextPrayer, .shortcuts, .continueReading, .lastActivity, .prayerTracker,
             .islamicCalendar:
            true
        case .ayahOfDay, .hadithOfDay, .duaOfDay:
            false
        }
    }
}
