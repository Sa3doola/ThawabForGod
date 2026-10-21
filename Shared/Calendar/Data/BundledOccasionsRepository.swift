//
//  BundledOccasionsRepository.swift
//  ThawabForGod
//

import Foundation

/// Reads the occasions out of `IslamicEvents.json` — the same file the Home header's
/// `IslamicEventTable` reads, so there is one list of occasions and not two.
///
/// Extra fields are optional on purpose: an entry with only `month` and `day` is the original
/// shape and becomes a `fixedDay` rule. A malformed entry is skipped rather than trapping, and
/// `IslamicOccasionsRepositoryTests` is what keeps that from happening silently.
nonisolated struct BundledOccasionsRepository: IslamicOccasionsRepositoring {

    private let loaded: [IslamicOccasion]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: IslamicEventTable.resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Lossy<Entry>].self, from: data) else {
            loaded = []
            return
        }
        loaded = entries.compactMap { $0.value?.occasion }
    }

    func occasions() -> [IslamicOccasion] { loaded }

    private struct Entry: Decodable {
        let id: String
        let nameKey: L10nKey
        let noteKey: L10nKey?
        let month: Int?
        let day: Int?
        let category: OccasionCategory
        let rule: OccasionRule?
        let summaryKey: L10nKey?
        let virtueKey: L10nKey?
        let sources: [OccasionSource]?
        let scholarlyNoteKey: L10nKey?

        var occasion: IslamicOccasion? {
            guard let rule = rule ?? month.flatMap({ m in day.map { OccasionRule.fixedDay(month: m, day: $0) } })
            else { return nil }
            return IslamicOccasion(
                id: id, nameKey: nameKey, category: category, rule: rule, noteKey: noteKey,
                summaryKey: summaryKey, virtueKey: virtueKey, sources: sources ?? [],
                scholarlyNoteKey: scholarlyNoteKey
            )
        }
    }
}
