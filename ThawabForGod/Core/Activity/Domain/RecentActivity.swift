//
//  RecentActivity.swift
//  ThawabForGod
//

import Foundation

/// The three things a user does in this app that they might want to pick back up.
nonisolated enum ActivityKind: String, CaseIterable, Codable, Sendable {
    case quran
    case adhkar
    case tasbih

    /// The heading on the chip. Reused from each feature's own title, so a chip and the screen it
    /// opens cannot disagree about what that screen is called.
    var titleKey: L10nKey {
        switch self {
        case .quran: .quranTitle
        case .adhkar: .adhkarTitle
        case .tasbih: .tasbihTitle
        }
    }

    var symbol: String {
        switch self {
        case .quran: "book"
        case .adhkar: "hands.sparkles"
        case .tasbih: "circle.hexagonpath"
        }
    }
}

/// Where a user got to, in one of the three.
///
/// **One row per kind, and the kind is the identity.** Recording a new Quran activity replaces
/// the previous one rather than appending, so the section can never fill with a hundred
/// near-identical rows — which is what an append-only log of "you read a verse" would become
/// within a single sitting.
///
/// **Nothing here is a display string.** `subject` is an identifier its own feature can read back,
/// and the numbers are numbers; the words and the digits are resolved when the chip is drawn.
/// The alternative — storing "البقرة – آية ١٤٢" at write time — would freeze the language *and*
/// the digit system at the moment of writing, and this app treats both as choices the user makes
/// later and changes freely.
nonisolated struct RecentActivity: Equatable, Sendable, Identifiable {
    let kind: ActivityKind

    /// Which item, as that feature identifies it: `"2:142"` for a verse, `"morning"` for an
    /// adhkar category, a preset's own id for the tasbih. Opaque to everything except the
    /// accessors below.
    let subject: String

    /// How far through it, and out of how much. Both zero means "no progress worth drawing" —
    /// see `fraction`.
    let progressValue: Int
    let progressTotal: Int

    let occurredAt: Date

    var id: ActivityKind { kind }

    init(
        kind: ActivityKind,
        subject: String,
        progressValue: Int,
        progressTotal: Int,
        occurredAt: Date
    ) {
        self.kind = kind
        self.subject = subject
        self.progressValue = progressValue
        self.progressTotal = progressTotal
        self.occurredAt = occurredAt
    }

    /// How full the chip's bar is, or `nil` where a bar would mean nothing.
    ///
    /// Clamped rather than trusted: a corpus rebuild could shorten a chapter under a stored
    /// position, and a bar drawn past its end is a worse way to find that out than a full one.
    var fraction: Double? {
        guard progressTotal > 0 else { return nil }
        return min(max(Double(progressValue) / Double(progressTotal), 0), 1)
    }

    /// Where tapping the chip goes.
    ///
    /// Optional because `subject` is a string and a corrupted one has no destination — the
    /// section drops a chip it cannot route rather than offering a tap that does nothing.
    var route: AppRoute? {
        switch kind {
        case .quran:
            verseReference.map(AppRoute.quranVerse)
        case .adhkar:
            adhkarCategory.map(AppRoute.adhkar)
        case .tasbih:
            .tasbih
        }
    }

    // MARK: The Quran

    static func quran(
        _ reference: VerseReference,
        of verseCount: Int,
        at date: Date
    ) -> RecentActivity {
        RecentActivity(
            kind: .quran,
            subject: "\(reference.surah):\(reference.verse)",
            progressValue: reference.verse,
            progressTotal: verseCount,
            occurredAt: date
        )
    }

    var verseReference: VerseReference? {
        let parts = subject.split(separator: ":")

        guard kind == .quran,
              parts.count == 2,
              let surah = Int(parts[0]),
              let verse = Int(parts[1]) else {
            return nil
        }

        return VerseReference(surah: surah, verse: verse)
    }

    // MARK: The adhkar

    static func adhkar(
        _ category: AdhkarCategory,
        completed: Int,
        of total: Int,
        at date: Date
    ) -> RecentActivity {
        RecentActivity(
            kind: .adhkar,
            subject: category.rawValue,
            progressValue: completed,
            progressTotal: total,
            occurredAt: date
        )
    }

    var adhkarCategory: AdhkarCategory? {
        guard kind == .adhkar else { return nil }
        return AdhkarCategory(rawValue: subject)
    }

    // MARK: The tasbih

    static func tasbih(
        dhikrID: String,
        count: Int,
        of target: Int,
        at date: Date
    ) -> RecentActivity {
        RecentActivity(
            kind: .tasbih,
            subject: dhikrID,
            progressValue: count,
            progressTotal: target,
            occurredAt: date
        )
    }

    var tasbihDhikrID: String? {
        kind == .tasbih ? subject : nil
    }
}
