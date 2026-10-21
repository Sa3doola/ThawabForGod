//
//  IslamicOccasion.swift
//  ThawabForGod
//

import Foundation

nonisolated enum OccasionCategory: String, Codable, CaseIterable, Sendable {
    case eid, fasting, night, season, historical

    var labelKey: L10nKey {
        switch self {
        case .eid: .occasionCategoryEid
        case .fasting: .occasionCategoryFasting
        case .night: .occasionCategoryNight
        case .season: .occasionCategorySeason
        case .historical: .occasionCategoryHistorical
        }
    }
}

/// The collections a source can cite. A closed list, so a work is always one the app has a name
/// for in both languages.
nonisolated enum OccasionWork: String, Codable, Sendable {
    case sahihBukhari = "sahih_bukhari"
    case sahihMuslim = "sahih_muslim"
    case jamiTirmidhi = "jami_tirmidhi"

    var labelKey: L10nKey {
        switch self {
        case .sahihBukhari: .workSahihBukhari
        case .sahihMuslim: .workSahihMuslim
        case .jamiTirmidhi: .workJamiTirmidhi
        }
    }
}

/// Who graded the report, said in the label. Only gradings the app can attribute to a classical
/// source: the two Sahihs by their compilers' conditions, al-Tirmidhi on his own report.
nonisolated enum OccasionGrading: String, Codable, Sendable {
    case sahih
    case hasanTirmidhi = "hasan_tirmidhi"

    var labelKey: L10nKey {
        switch self {
        case .sahih: .gradingSahih
        case .hasanTirmidhi: .gradingHasanTirmidhi
        }
    }
}

nonisolated struct OccasionSource: Codable, Equatable, Sendable {
    let work: OccasionWork
    /// The published hadith number, as sunnah.com numbers it.
    let reference: String
    let grading: OccasionGrading?
}

/// An occasion in the Islamic year: what it is, when it falls, and what may be said about it.
///
/// Text is all `L10nKey`. A `virtueKey` is never present without `sources`, each with a grading —
/// `IslamicOccasionsRepositoryTests` holds the bundled table to that, because an unsourced virtue
/// would carry the app's implicit assurance with it.
nonisolated struct IslamicOccasion: Identifiable, Equatable, Sendable {
    let id: String
    let nameKey: L10nKey
    let category: OccasionCategory
    let rule: OccasionRule
    let noteKey: L10nKey?
    let summaryKey: L10nKey?
    let virtueKey: L10nKey?
    let sources: [OccasionSource]
    let scholarlyNoteKey: L10nKey?

    var isRecurring: Bool { rule.isRecurring }
}
