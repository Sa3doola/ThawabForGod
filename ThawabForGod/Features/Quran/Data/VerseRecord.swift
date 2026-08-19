//
//  VerseRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `verse` table, as SQLite stores it.
///
/// `textNormalized` is deliberately absent. The column exists — it is what the FTS5 index is
/// built over — but nothing above this layer has any use for a folded copy of the text, and a
/// second megabyte of Arabic on every scroll is a cost with no reader on the other end of it.
nonisolated struct VerseRecord: FetchableRecord, Sendable, Equatable {
    let surahNumber: Int
    let number: Int
    let text: String
    let juz: Int
    let hizb: Int
    let rubElHizb: Int
    let page: Int
    let sajda: String?

    init(row: Row) {
        surahNumber = row["surah_id"]
        number = row["number"]
        text = row["text"]
        juz = row["juz"]
        hizb = row["hizb"]
        rubElHizb = row["rub_el_hizb"]
        page = row["page"]
        sajda = row["sajda"]
    }

    /// Memberwise, for the mapper's tests.
    init(
        surahNumber: Int,
        number: Int,
        text: String,
        juz: Int,
        hizb: Int,
        rubElHizb: Int,
        page: Int,
        sajda: String?
    ) {
        self.surahNumber = surahNumber
        self.number = number
        self.text = text
        self.juz = juz
        self.hizb = hizb
        self.rubElHizb = rubElHizb
        self.page = page
        self.sajda = sajda
    }
}

nonisolated extension VerseRecord {

    /// An unrecognised sajda kind reads as no sajda rather than as a guess.
    ///
    /// The opposite call from `SurahRecord`, and for the same reason: a chapter with no
    /// revelation place cannot be drawn at all, but a verse whose prostration mark this build
    /// does not understand is still the verse, and dropping it would take the text away over a
    /// marginal note about it.
    var domainValue: Verse {
        Verse(
            id: VerseReference(surah: surahNumber, verse: number),
            text: text,
            juz: juz,
            hizb: hizb,
            rubElHizb: rubElHizb,
            page: page,
            sajda: sajda.flatMap(Sajda.init(rawValue:))
        )
    }
}
