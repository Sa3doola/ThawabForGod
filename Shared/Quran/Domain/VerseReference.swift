//
//  VerseReference.swift
//  ThawabForGod
//

import Foundation

/// A verse's address: which chapter, which verse in it.
///
/// Its own type rather than a pair of `Int`s, because every navigation path to a verse — a search
/// result, a bookmark, "continue reading", a deep link — carries one, and two bare integers in a
/// row are exactly the kind of thing that gets passed in the wrong order.
///
/// **In `Shared/` rather than the Quran feature** because a second process needs it: a widget that
/// names the ayah of the day, and the `DeepLink` that opens one, both have to say which verse, and
/// neither can see `Features/`. It is Foundation alone, which is the test `Shared/` applies.
///
/// It is also Mushaf's `AyahID` under this project's name (QURAN_MIGRATION_PLAN.md, T7): one name
/// for one concept, so `AppRoute.quranVerse` and the activity rows written before the port still
/// resolve. Its `description` — `"2:255"` — is the form `RecentActivity` stores as a subject, so
/// that string is a storage format and not only a debugging aid.
nonisolated struct VerseReference: Hashable, Sendable, Comparable, Codable, Identifiable, CustomStringConvertible {
    let surah: Int
    let verse: Int

    /// Itself: a verse's address *is* its identity, so a separate one would be a second thing to
    /// keep in step. It is what `sheet(item:)` presents a verse's panel on.
    var id: Self { self }

    init(surah: Int, verse: Int) {
        self.surah = surah
        self.verse = verse
    }

    /// What a reader typed — `2:255`, `٢:٢٥٥`, `2/255` — or `nil` when it is not two numbers.
    ///
    /// It accepts any of the three digit systems because the reader's keyboard decides which one
    /// arrives, not the app's number setting. It does **not** check the chapter has that many
    /// verses: this type is an address, and whether an address exists is the corpus's question.
    init?(parsing text: String) {
        let parts = text.split(whereSeparator: { $0 == ":" || $0 == "/" || $0 == " " })
        guard parts.count == 2,
              let surah = Int(normalizingDigits: String(parts[0])),
              let verse = Int(normalizingDigits: String(parts[1]))
        else { return nil }
        self.init(surah: surah, verse: verse)
    }

    /// Reading order, which is the order the mushaf is in.
    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.surah, lhs.verse) < (rhs.surah, rhs.verse)
    }

    /// `2:255`, in ASCII digits whatever the reader's number system — it is stored and parsed, so a
    /// displayed reference goes through `LocalizationManager` instead.
    var description: String { "\(surah):\(verse)" }
}

extension Int {
    /// A whole number typed in ASCII, Arabic-Indic (٠–٩) or Extended Arabic-Indic (۰–۹) digits;
    /// `nil` for anything else, signs included.
    ///
    /// Input parsing rather than formatting, which is why it is not on `LocalizationManager`: what
    /// a reader types follows their keyboard, while what the app draws follows their setting.
    nonisolated init?(normalizingDigits text: String) {
        var ascii = ""
        for scalar in text.trimmingCharacters(in: .whitespaces).unicodeScalars {
            switch scalar.value {
            case 0x30...0x39: ascii.unicodeScalars.append(scalar)
            case 0x0660...0x0669: ascii.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x0660 + 0x30)!)
            case 0x06F0...0x06F9: ascii.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x06F0 + 0x30)!)
            default: return nil
            }
        }
        self.init(ascii)
    }
}
