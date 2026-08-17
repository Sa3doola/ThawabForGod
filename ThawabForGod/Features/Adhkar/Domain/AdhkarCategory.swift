//
//  AdhkarCategory.swift
//  ThawabForGod
//

import Foundation

/// A heading in the adhkar corpus, and the unit the reading screen works through.
///
/// The raw value is the `category.id` stored in the bundled database, which is what lets the
/// repository turn a row into a case and back. That indirection is the point: **which**
/// categories exist is data, and the bundled corpus today carries only the two below.
///
/// Hisn al-Muslim has many more — after prayer, before sleep, on waking, entering and leaving
/// the home, meals — and none of them are in the upstream data set this ships with (see
/// `Resources/Corpus/README.md`). They are absent here rather than listed and empty, because a
/// category with no adhkar behind it is a row the reader taps to reach a blank screen. Adding
/// one is a rebuild of the database plus a case here, in that order.
nonisolated enum AdhkarCategory: String, CaseIterable, Identifiable, Sendable {
    case morning
    case evening

    var id: String { rawValue }

    /// The heading as a key, resolved to Arabic or English at display time — the same treatment
    /// prayer names and Islamic events get. Only the *category* names are translated this way;
    /// the adhkar themselves come out of the corpus, not the string catalog.
    var titleKey: L10nKey {
        switch self {
        case .morning: .adhkarCategoryMorning
        case .evening: .adhkarCategoryEvening
        }
    }

    /// A one-line note on when the category is read, shown under its title.
    var subtitleKey: L10nKey {
        switch self {
        case .morning: .adhkarCategoryMorningSubtitle
        case .evening: .adhkarCategoryEveningSubtitle
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise"
        case .evening: "sunset"
        }
    }
}
