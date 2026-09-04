//
//  HomeShortcut.swift
//  ThawabForGod
//

import Foundation

/// The features Home can offer as a one-tap circle.
///
/// A separate collection from `HomeSectionKind` rather than more cases on it, because the two
/// are ordered and toggled independently: the shortcuts section is one row of the layout, and
/// this is what is inside it. The customization screen edits both, in two lists.
///
/// Same forward-compatibility contract as the sections — `islamicCalendar` and `hadith` are
/// declared before the screens they would open, so shipping either is a change to
/// `isAvailable` and nothing else.
nonisolated enum HomeShortcut: String, CaseIterable, Codable, Sendable {
    /// Straight into أذكار الصباح والمساء, the one chapter this shortcut has always meant.
    ///
    /// The raw value is still `morningAdhkar`, deliberately: it is what a user's stored
    /// arrangement holds, and renaming the case without pinning it would move the circle back to
    /// the end of everybody's grid. The `eveningAdhkar` case that stood beside it is **withdrawn**
    /// — Hisn al-Muslim has one chapter for both times of day, not two, so the second circle would
    /// have been a different label on the same destination. A stored preference naming it is
    /// dropped by `HomeLayout.reconciled(_:)`, the same way a withdrawn section's is.
    case morningEveningAdhkar = "morningAdhkar"
    case tasbih
    case qibla
    case namesOfAllah
    case islamicCalendar
    case hadith

    /// Whether the feature behind this shortcut exists yet. An unavailable shortcut appears
    /// neither on Home nor in the editor.
    var isAvailable: Bool {
        switch self {
        case .morningEveningAdhkar, .tasbih, .qibla, .namesOfAllah:
            true
        case .islamicCalendar, .hadith:
            false
        }
    }

    /// Whether a fresh install shows this shortcut.
    var defaultVisibility: Bool { isAvailable }

    /// What tapping it opens, or `nil` for a shortcut whose feature does not exist yet.
    ///
    /// Optional rather than a fatal default, because the two reserved cases genuinely have
    /// nowhere to go — and an enum that had to invent a destination for them would be a lie the
    /// compiler could not catch. The grid never draws an unavailable shortcut, so the `nil` is
    /// unreachable in practice and stays honest on paper.
    var route: AppRoute? {
        switch self {
        case .morningEveningAdhkar: .adhkar(categoryID: AdhkarCategory.morningAndEveningID)
        case .tasbih: .tasbih
        case .qibla: .qibla
        case .namesOfAllah: .names
        case .islamicCalendar, .hadith: nil
        }
    }

    /// The label under the circle.
    ///
    /// Reused from the screens themselves wherever those names already stand alone — the tasbih,
    /// the Qibla, the 99 names. The adhkar chapter is the exception and gets a label of its own:
    /// on its own screen it sits under an "Adhkar" heading, but in a grid of unrelated circles
    /// the heading is not there to lean on, so the label says which adhkar.
    var labelKey: L10nKey {
        switch self {
        case .morningEveningAdhkar: .homeShortcutMorningEveningAdhkar
        case .tasbih: .tasbihTitle
        case .qibla: .qiblaTitle
        case .namesOfAllah: .namesTitle
        case .islamicCalendar: .homeSectionIslamicCalendar
        case .hadith: .homeSectionHadithOfDay
        }
    }

    /// The SF Symbol inside the circle. A plain string, so naming it here costs Domain no
    /// import — the same trade `Prayer.symbol` and `AppTab.symbol` make.
    var symbol: String {
        switch self {
        case .morningEveningAdhkar: "sun.horizon"
        case .tasbih: "circle.hexagonpath"
        case .qibla: "location.north.line"
        case .namesOfAllah: "sparkles"
        case .islamicCalendar: "calendar"
        case .hadith: "text.book.closed"
        }
    }
}
