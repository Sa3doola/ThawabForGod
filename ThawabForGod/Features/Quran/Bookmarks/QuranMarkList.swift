//
//  QuranMarkList.swift
//  ThawabForGod
//

import Foundation

/// Which of the reader's three kinds of mark the Bookmarks screen lists. Ported from Mushaf's
/// `BookmarkKind`.
nonisolated enum QuranMarkKind: String, CaseIterable, Identifiable, Sendable {
    case bookmarks, notes, highlights

    var id: String { rawValue }

    var titleKey: L10nKey {
        switch self {
        case .bookmarks: .quranMarksBookmarks
        case .notes: .quranMarksNotes
        case .highlights: .quranMarksHighlights
        }
    }

    var emptyKey: L10nKey {
        switch self {
        case .bookmarks: .quranMarksEmptyBookmarks
        case .notes: .quranMarksEmptyNotes
        case .highlights: .quranMarksEmptyHighlights
        }
    }

    var systemImage: String {
        switch self {
        case .bookmarks: "bookmark"
        case .notes: "note.text"
        case .highlights: "highlighter"
        }
    }
}

/// How the list is ordered. Ported from Mushaf's `BookmarkOrder`.
nonisolated enum QuranMarkOrder: String, CaseIterable, Identifiable, Sendable {
    case date, surah

    var id: String { rawValue }

    var titleKey: L10nKey {
        switch self {
        case .date: .quranMarksByDate
        case .surah: .quranMarksBySurah
        }
    }
}

/// One mark, reduced to what a row draws. Never carries Quran text.
nonisolated struct QuranMarkRow: Identifiable, Hashable, Sendable {
    let ayah: VerseReference
    /// A bookmark's `createdAt`; a note's or highlight's `updatedAt`.
    let date: Date
    var note: String?
    var color: HighlightColor?

    var id: VerseReference { ayah }
}

nonisolated struct QuranMarkSection: Identifiable, Hashable, Sendable {
    /// 0 when the rows are ordered by date and belong to no surah in particular.
    let surah: Int
    let rows: [QuranMarkRow]

    var id: Int { surah }
}

/// The ordering rule as a pure function, so no view is needed to test it.
nonisolated enum QuranMarkList {
    static func sections(_ rows: [QuranMarkRow], order: QuranMarkOrder) -> [QuranMarkSection] {
        guard !rows.isEmpty else { return [] }
        switch order {
        case .date:
            let sorted = rows.sorted {
                $0.date != $1.date ? $0.date > $1.date : $0.ayah < $1.ayah
            }
            return [QuranMarkSection(surah: 0, rows: sorted)]
        case .surah:
            return Dictionary(grouping: rows, by: { $0.ayah.surah })
                .map { surah, group in
                    QuranMarkSection(surah: surah, rows: group.sorted { $0.ayah < $1.ayah })
                }
                .sorted { $0.surah < $1.surah }
        }
    }
}
