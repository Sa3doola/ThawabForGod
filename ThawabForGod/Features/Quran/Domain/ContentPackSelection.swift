//
//  ContentPackSelection.swift
//  ThawabForGod
//

import Foundation

/// Which bundled packs of one kind are shown, and in what order (Settings → Translations &
/// Tafsir). Pure: the view edits it and writes `enabled` back to `QuranReaderSettings`.
///
/// Ported from Mushaf. No SwiftUI: `move` is written by hand because
/// `MutableCollection.move(fromOffsets:toOffset:)` belongs to SwiftUI.
nonisolated struct ContentPackSelection: Equatable, Sendable {
    nonisolated struct Row: Identifiable, Equatable, Sendable {
        let pack: ContentPack
        var isEnabled: Bool
        var id: ContentPackID { pack.id }
    }

    /// Enabled packs first in the user's order, then the others in manifest order.
    private(set) var rows: [Row]

    /// - Parameter enabled: the stored order; nil means every installed pack, in manifest order.
    ///   Ids that are no longer bundled are ignored.
    init(installed: [ContentPack], enabled: [ContentPackID]?) {
        let order = enabled ?? installed.map(\.id)
        let on = order.compactMap { id in installed.first { $0.id == id } }
        let off = installed.filter { pack in !order.contains(pack.id) }
        rows = on.map { Row(pack: $0, isEnabled: true) } + off.map { Row(pack: $0, isEnabled: false) }
    }

    /// The value to store as the enabled list.
    var enabled: [ContentPackID] {
        rows.filter(\.isEnabled).map(\.id)
    }

    /// The installed packs the reader has switched on, in their order. `nil` means all of them, in
    /// store order; `[]` means none. Ids that are not installed are skipped.
    static func enabledPacks(installed: [ContentPack], enabled: [ContentPackID]?) -> [ContentPack] {
        guard let enabled else { return installed }
        return enabled.compactMap { id in installed.first { $0.id == id } }
    }

    mutating func setEnabled(_ isEnabled: Bool, for pack: ContentPackID) {
        guard let index = rows.firstIndex(where: { $0.id == pack }) else { return }
        rows[index].isEnabled = isEnabled
    }

    /// Reorders like `List.onMove`: `destination` is an index in the array as it was before the move.
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().map { rows[$0] }
        let before = source.filter { $0 < destination }.count
        for index in source.sorted().reversed() { rows.remove(at: index) }
        rows.insert(contentsOf: moving, at: destination - before)
    }
}
