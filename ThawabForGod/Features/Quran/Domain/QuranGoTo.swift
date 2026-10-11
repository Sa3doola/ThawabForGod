//
//  QuranGoTo.swift
//  ThawabForGod
//

import ArabicText
import Foundation

/// What the text in the Library's field is, decided once per edit.
///
/// The field does two jobs: it goes to an address and it narrows the surah names. Which one a
/// half-typed string means decides whether the list filters and whether the tab moves, and the
/// answer must not flicker while a reader is part-way through `juz 5`.
nonisolated enum QuranGoToInput: Equatable, Sendable {
    case empty
    /// Digits only, in any of the three digit systems.
    case number(Int)
    /// A complete address ("juz 5", "2:255"), or text that can still become one.
    case address
    /// Anything else: a surah name to filter by.
    case name

    init(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self = .empty
        } else if let number = Int(normalizingDigits: trimmed) {
            self = .number(number)
        } else if Self.isCompleteAddress(trimmed) || Self.isPrefixOfUnitWord(trimmed) {
            self = .address
        } else {
            self = .name
        }
    }

    /// A complete address: a unit and its number, `s:a`, or a number followed by a separator.
    fileprivate static func isCompleteAddress(_ trimmed: String) -> Bool {
        GoToTarget.unitAndNumber(trimmed) != nil
            || VerseReference(parsing: trimmed) != nil
            || trimmed.wholeMatch(of: #/[\d٠-٩۰-۹]+[:/][\d٠-٩۰-۹]*/#) != nil
    }

    /// `j`, `ju`, `juz.`, `ال`: still on the way to a unit word. The cost is a delay of a letter or
    /// two for the few names that begin like one (`hijr` filters from its third letter), which
    /// `QuranGoTo.input(_:among:)` waives for a text that is a surah's whole name (`ص`).
    fileprivate static func isPrefixOfUnitWord(_ text: String) -> Bool {
        var typed = text.lowercased()
        if typed.hasSuffix(".") { typed.removeLast() }
        guard !typed.isEmpty else { return false }
        return GoToTarget.Unit.allCases.contains { unit in
            unit.words.contains { $0.hasPrefix(typed) }
        }
    }
}

nonisolated enum QuranGoToFailure: Equatable, Sendable {
    case notFound
    /// A page was asked of a build that has no printed pages.
    case pagesUnavailable
}

nonisolated enum QuranGoToOutcome: Equatable, Sendable {
    case go(GoToTarget)
    case failed(QuranGoToFailure)
}

/// What submit does with the field's text, and the surah filter that narrows the list under it.
/// Pure, so both databases can be tested against it with no view model.
nonisolated enum QuranGoTo {
    /// In order: a page asked for by name in a build without pages is refused; then the address
    /// parser; then the one surah the filter leaves, if exactly one; otherwise not found.
    ///
    /// A bare number is not "asking for a page" in the public build: `GoToTarget.parse` finds no
    /// page for it, and the filter leaves the surah with that number. A page is refused only when
    /// the reader says "page", so no page number is ever mapped in a build that has none.
    static func resolve(_ text: String, corpus: QuranCorpus, index: QuranLibraryIndex) -> QuranGoToOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !index.showsPages, GoToTarget.unitAndNumber(trimmed)?.0 == .page {
            return .failed(.pagesUnavailable)
        }
        if let target = GoToTarget.parse(trimmed, in: corpus) {
            // Cannot happen today, since the corpus has no page to find. The guard is the design
            // saying so, rather than leaving it to the parser's behaviour.
            if !index.showsPages, case .page = target { return .failed(.pagesUnavailable) }
            return .go(target)
        }
        let matches = surahs(index.surahs, matching: trimmed)
        if matches.count == 1, let only = matches.first { return .go(.surah(only.surah.number)) }
        // A whole name wins over containment: ص is inside the names of several surahs and is
        // the whole name of only one.
        let exact = matches.filter { isWholeName(trimmed, of: $0) }
        if exact.count == 1, let only = exact.first { return .go(.surah(only.surah.number)) }
        return .failed(.notFound)
    }

    /// What `text` is, knowing the surahs. As `QuranGoToInput(text)`, except that text which is
    /// only an address in progress (a prefix of a unit word, not a complete address) and equals a
    /// surah's whole name, folded as the filter folds it, is `.name`.
    ///
    /// The exception exists because Surah 38 is named by the single letter ص, which is also a
    /// page keyword: without it the one surah whose whole name is one letter could not be found
    /// by typing it. `س`, `ح`, `ج`, `s`, `h`, `j` and `p` are no surah's whole name, so they stay
    /// addresses in progress.
    static func input(_ text: String, among surahs: [QuranLibrarySurahRow]) -> QuranGoToInput {
        let base = QuranGoToInput(text)
        guard base == .address else { return base }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !QuranGoToInput.isCompleteAddress(trimmed) else { return base }
        return surahs.contains { isWholeName(trimmed, of: $0) } ? .name : base
    }

    /// Equality, not containment, under the same folding the filter uses.
    private static func isWholeName(_ text: String, of row: QuranLibrarySurahRow) -> Bool {
        let latin = latinKey(text)
        let arabic = arabicKey(text)
        return (!latin.isEmpty && row.latinKey == latin) || (!arabic.isEmpty && row.arabicKey == arabic)
    }

    /// The rows the field leaves in the surah list. An address in progress narrows nothing.
    static func surahs(_ rows: [QuranLibrarySurahRow], matching text: String) -> [QuranLibrarySurahRow] {
        switch input(text, among: rows) {
        case .empty, .address:
            return rows
        case .number(let number):
            return rows.filter { $0.surah.number == number }
        case .name:
            let latin = latinKey(text)
            let arabic = arabicKey(text)
            return rows.filter { row in
                (!latin.isEmpty && row.latinKey.contains(latin))
                    || (!arabic.isEmpty && row.arabicKey.contains(arabic))
            }
        }
    }

    /// Lower-cased, ASCII letters only: "Ali 'Imran" and "imran" meet at `aliimran` / `imran`.
    static func latinKey(_ text: String) -> String {
        String(text.lowercased().unicodeScalars
            .filter { $0.isASCII && CharacterSet.lowercaseLetters.contains($0) }
            .map(Character.init))
    }

    /// Folded the way search folds (`ArabicNormalizer`: hamza forms, tashkeel), spaces removed.
    static func arabicKey(_ text: String) -> String {
        ArabicNormalizer.words(in: text).joined()
    }
}
