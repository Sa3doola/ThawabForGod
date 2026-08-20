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
}
