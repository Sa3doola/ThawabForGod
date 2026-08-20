//
//  HomeLayoutRepository.swift
//  ThawabForGod
//

import Foundation

/// The Home arrangement, as one JSON string in `SettingsStore`.
///
/// `SettingsStore` and not SwiftData, for the reason `OnboardingRepository` and `ReaderSettings`
/// are there too: this is a *preference*, and the project keeps every preference behind one
/// store. SwiftData is for what the user creates — bookmarks, counts, progress — and a layout is
/// not that.
///
/// One key holding the whole value rather than a key per section. `SettingsKey` is a closed enum,
/// so a key per section would mean nine cases that have to grow every time the enum does, and a
/// half-written layout would become representable in between two writes.
///
/// **Nothing is written until the user edits something.** `layout()` falls back to the default
/// without persisting it, which is what keeps "never customized" distinguishable from "chose what
/// the default happens to be" — see `SettingsStore`'s own notes on why that difference matters.
nonisolated struct HomeLayoutRepository: HomeLayoutRepositoring {
    private let settingsStore: any SettingsStore

    init(settingsStore: any SettingsStore) {
        self.settingsStore = settingsStore
    }

    func layout() -> HomeLayout {
        guard let stored = settingsStore.string(for: .homeLayout),
              let data = stored.data(using: .utf8),
              // Unreadable JSON falls back rather than trapping, the same way an unrecognised
              // `ReaderPaper` does. The decoder itself is tolerant of *unknown members* — see
              // `HomeLayout.init(from:)` — so reaching here means the string is not a layout at
              // all, which only a corrupted store can produce.
              let layout = try? JSONDecoder().decode(HomeLayout.self, from: data) else {
            return .default
        }

        return layout
    }

    func save(_ layout: HomeLayout) {
        guard let data = try? JSONEncoder().encode(layout),
              let json = String(data: data, encoding: .utf8) else { return }

        settingsStore.set(json, for: .homeLayout)
    }

    func reset() {
        settingsStore.set(nil as String?, for: .homeLayout)
    }
}
