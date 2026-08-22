//
//  AppTab.swift
//  ThawabForGod
//

import Foundation

/// The top-level sections of the app, one per tab.
///
/// Five of them, which is what a tab bar is for: each is a place the user *lives in* for a
/// while, not a screen they visit and come back from. That is the line this enum draws — the
/// Qibla, the tasbih and the 99 names stay pushed from Home's toolbar, because a glance at a
/// compass or a run of a dhikr ends by going back to where it started, and a permanent slot for
/// each would say otherwise. Reading hadith is on the other side of that line for the same
/// reason reading the Quran is: it is a sitting the reader returns to, and a tab is what
/// remembers where they were.
///
/// **Five is also the iPhone's limit**, past which UIKit folds the rest behind a "More" tab and
/// picks for you which ones. Nothing here enforces that, because nothing here should — but a
/// sixth case is a design decision about the whole app rather than an addition to a list.
///
/// `settings` is iOS and iPadOS only in practice. The Mac build reaches the same screen through
/// the `Settings` scene and ⌘, — where a Mac user looks for it — so `MainTabView` leaves that tab
/// out there rather than offering a second door to the same room. The case exists on both
/// platforms because a conditionally-compiled enum case buys nothing and costs every `switch`.
nonisolated enum AppTab: String, Hashable, CaseIterable, Sendable {
    case home
    case quran
    case hadith
    case adhkar
    case settings

    /// The SF Symbol the tab bar shows. Symbols rather than assets: they carry Dynamic Type and
    /// the platform's own filled/unfilled selection behaviour without a second copy of each icon.
    var symbol: String {
        switch self {
        case .home: "moon.stars"
        case .quran: "book.closed"
        case .hadith: "text.book.closed"
        case .adhkar: "hands.sparkles"
        case .settings: "gearshape"
        }
    }
}
