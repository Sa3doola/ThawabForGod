//
//  QuranSearchViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// The Quran search screen's session: what was typed, which scope, and what it found.
///
/// Ported from the state in Mushaf's `SearchView` (`Outcome`, the debounce, `run`), moved out of the
/// view so it can outlive it. One instance for the whole section, owned by `AppContainer`: the text,
/// the scope and the results survive opening a result, a tab switch, and an iPad crossing between
/// compact and regular width, and the search button shows the same screen it left (M5.5 design,
/// sections 3 and 5).
///
/// **Cancellation is the view's.** It runs `run()` under `.task(id: key)`, so SwiftUI cancels the
/// previous run whenever the key changes. After every `await` a run checks both that it was not
/// cancelled and that its key is still the current one, so a slow query can never overwrite a newer
/// answer.
@Observable
@MainActor
final class QuranSearchViewModel {
    nonisolated enum Outcome: Sendable {
        case idle, tooShort, failed
        /// Exact matches grouped by surah, then the ayahs found only with attached particles.
        case quran(QuranSearchQuery, exact: [SurahGroup<VerseReference>], attached: [SurahGroup<VerseReference>], count: Int)
        /// `count` is the number of distinct ayahs, not of rows: an ayah in two packs is one result.
        case translations(QuranSearchQuery, [SurahGroup<TranslationText>], count: Int, packs: [ContentPack])
    }

    nonisolated struct Key: Hashable, Sendable {
        let text: String
        let scope: QuranSearchScope
    }

    /// Debounce before a search runs while typing.
    static let debounce: Duration = .milliseconds(250)

    var text = ""
    var scope: QuranSearchScope = .quran

    private(set) var outcome: Outcome = .idle
    private(set) var isSearching = false
    /// `.quran` until `prepare()` has looked at the packs; then `.translations` too if one is installed.
    private(set) var availableScopes: [QuranSearchScope] = [.quran]

    @ObservationIgnored private let search: any QuranSearchRepositoring
    @ObservationIgnored private let translations: any TranslationRepositoring
    @ObservationIgnored private let reader: QuranReaderViewModel
    @ObservationIgnored private var packs: [ContentPack] = []
    @ObservationIgnored private var didPrepare = false
    /// The key whose outcome `outcome` holds, so coming back to the screen with nothing changed does
    /// not search again.
    @ObservationIgnored private var lastAppliedKey: Key?

    init(search: any QuranSearchRepositoring, translations: any TranslationRepositoring, reader: QuranReaderViewModel) {
        self.search = search
        self.translations = translations
        self.reader = reader
    }

    var key: Key { Key(text: text, scope: scope) }

    /// The reader's corpus: ayah text and surah names for the rows. `nil` until it has loaded.
    var corpus: QuranCorpus? { reader.corpus }

    /// Loads the corpus and the installed translation packs, once.
    func prepare() async {
        await reader.load()
        guard !didPrepare else { return }
        didPrepare = true
        // No enabled list until M5.6: every installed translation, in the order the store gives.
        packs = await translations.installed().filter { $0.kind == .translation }
        availableScopes = packs.isEmpty ? [.quran] : [.quran, .translations]
    }

    /// Opens the screen on the given words, in the Arabic scope (the Library's handoff).
    func prefill(_ text: String) {
        self.text = text
        scope = .quran
    }

    func run() async {
        let key = self.key
        guard key != lastAppliedKey else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            apply(.idle, for: key)
            return
        }
        guard let query = QuranSearchQuery(trimmed, scope: scope) else {
            apply(.tooShort, for: key)
            return
        }
        do {
            try await Task.sleep(for: Self.debounce)
        } catch {
            return
        }
        guard isCurrent(key) else { return }
        isSearching = true
        do {
            let result: Outcome
            switch key.scope {
            case .quran:
                let found = try await search.searchQuran(query)
                guard isCurrent(key) else { return stop(key) }
                let exact = await Self.group(found.exact) { $0 }
                let attached = await Self.group(found.attached) { $0 }
                result = .quran(query, exact: exact, attached: attached, count: found.count)
            case .translations:
                let packs = self.packs
                let hits = try await search.searchTranslations(query, packs: packs.map(\.id))
                guard isCurrent(key) else { return stop(key) }
                let groups = await Self.group(hits) { $0.ayah }
                result = .translations(query, groups, count: Set(hits.map(\.ayah)).count, packs: packs)
            }
            guard isCurrent(key) else { return stop(key) }
            apply(result, for: key)
        } catch is CancellationError {
            stop(key)
        } catch {
            guard isCurrent(key) else { return stop(key) }
            apply(.failed, for: key)
        }
    }

    // MARK: Private

    private func isCurrent(_ key: Key) -> Bool {
        !Task.isCancelled && key == self.key
    }

    private func apply(_ outcome: Outcome, for key: Key) {
        self.outcome = outcome
        lastAppliedKey = key
        isSearching = false
    }

    /// A run ending without an answer. Clears the spinner only if nothing newer has taken over; a
    /// run superseded by a new key leaves it to the run that replaced it.
    private func stop(_ key: Key) {
        if key == self.key { isSearching = false }
    }

    /// Grouping by surah over up to ~2,700 hits ("الله"), off the main actor.
    @concurrent
    nonisolated private static func group<Item: Sendable>(
        _ items: [Item],
        ayah: @Sendable (Item) -> VerseReference
    ) async -> [SurahGroup<Item>] {
        SurahGroup.groups(items, ayah: ayah)
    }
}
