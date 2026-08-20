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
    case morningAdhkar
    case eveningAdhkar
    case tasbih
    case qibla
    case namesOfAllah
    case islamicCalendar
    case hadith

    /// Whether the feature behind this shortcut exists yet. An unavailable shortcut appears
    /// neither on Home nor in the editor.
    var isAvailable: Bool {
        switch self {
        case .morningAdhkar, .eveningAdhkar, .tasbih, .qibla, .namesOfAllah:
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
        case .morningAdhkar: .adhkar(.morning)
        case .eveningAdhkar: .adhkar(.evening)
        case .tasbih: .tasbih
        case .qibla: .qibla
        case .namesOfAllah: .names
        case .islamicCalendar, .hadith: nil
        }
    }

    /// The label under the circle.
    ///
    /// Reused from the screens themselves wherever those names already stand alone — the tasbih,
    /// the Qibla, the 99 names. The two adhkar categories are the exception and get labels of
    /// their own: on their own screen they sit under an "Adhkar" heading and "Morning" is enough,
    /// but in a grid of unrelated circles "Morning" and "Evening" name nothing at all.
    var labelKey: L10nKey {
        switch self {
        case .morningAdhkar: .homeShortcutMorningAdhkar
        case .eveningAdhkar: .homeShortcutEveningAdhkar
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
        case .morningAdhkar: "sunrise"
        case .eveningAdhkar: "sunset"
        case .tasbih: "circle.hexagonpath"
        case .qibla: "location.north.line"
        case .namesOfAllah: "sparkles"
        case .islamicCalendar: "calendar"
        case .hadith: "text.book.closed"
        }
    }
}
