//
//  AdhkarGroup.swift
//  ThawabForGod
//

import Foundation

/// How the 132 chapters of Hisn al-Muslim are broken up for browsing.
///
/// **The book has no such thing.** It is one flat sequence, which works bound in the hand and
/// does not work as 132 rows on a phone — a reader looking for the dua on entering the market
/// has no way to arrive at it. So the grouping is this project's, applied over the book's own
/// order rather than replacing it: `AdhkarCategory.sortOrder` is still Hisn al-Muslim's chapter
/// number, and a group is only where the list is cut.
///
/// Which chapter belongs to which group is **data** — `Tools/CorpusBuilder/data/adhkar_categories.json`
/// — so the assignment is a diff somebody can argue with rather than a `switch` buried in a view.
/// This enum is the app's half of that contract: the raw value is the `category_group.id` stored
/// in the corpus, and a group the build ships that this build has no case for is dropped rather
/// than trapped, the same way an unknown category is.
nonisolated enum AdhkarGroup: String, CaseIterable, Identifiable, Sendable {
    case daily
    case purification
    case prayer
    case home
    case food
    case travel
    case hajj
    case distress
    case illness
    case nature
    case social
    case praise

    var id: String { rawValue }

    /// The heading as a key, resolved at display time — the same treatment prayer names and
    /// Islamic events get. Only the *groups* are translated this way; a chapter's own title comes
    /// out of the corpus in both languages, and the adhkar themselves are Arabic only.
    var titleKey: L10nKey {
        switch self {
        case .daily: .adhkarGroupDaily
        case .purification: .adhkarGroupPurification
        case .prayer: .adhkarGroupPrayer
        case .home: .adhkarGroupHome
        case .food: .adhkarGroupFood
        case .travel: .adhkarGroupTravel
        case .hajj: .adhkarGroupHajj
        case .distress: .adhkarGroupDistress
        case .illness: .adhkarGroupIllness
        case .nature: .adhkarGroupNature
        case .social: .adhkarGroupSocial
        case .praise: .adhkarGroupPraise
        }
    }

    var symbolName: String {
        switch self {
        case .daily: "sunrise"
        case .purification: "drop"
        case .prayer: "building.columns"
        case .home: "house"
        case .food: "fork.knife"
        case .travel: "airplane"
        case .hajj: "mappin.and.ellipse"
        case .distress: "cloud.bolt"
        case .illness: "cross.case"
        case .nature: "cloud.sun"
        case .social: "person.2"
        case .praise: "sparkles"
        }
    }
}
