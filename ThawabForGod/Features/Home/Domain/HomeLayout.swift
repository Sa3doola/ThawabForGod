//
//  HomeLayout.swift
//  ThawabForGod
//

import Foundation

/// One section's place in the stack: which section, and whether the user wants it.
///
/// Order is not in here — it is the order of the array in `HomeLayout`, which is what a
/// drag-to-reorder list produces and what a stored index would only duplicate and let drift.
nonisolated struct HomeSectionPreference: Equatable, Identifiable, Sendable {
    let kind: HomeSectionKind
    var isVisible: Bool

    var id: HomeSectionKind { kind }

    init(kind: HomeSectionKind, isVisible: Bool) {
        self.kind = kind
        self.isVisible = isVisible
    }
}

/// The same, for one shortcut circle.
nonisolated struct HomeShortcutPreference: Equatable, Identifiable, Sendable {
    let shortcut: HomeShortcut
    var isVisible: Bool

    var id: HomeShortcut { shortcut }

    init(shortcut: HomeShortcut, isVisible: Bool) {
        self.shortcut = shortcut
        self.isVisible = isVisible
    }
}

/// How this user has arranged Home: which sections, in what order, and which shortcuts.
///
/// The type is the *rules*, not just the data. Every mutation goes through a method here rather
/// than through a settable property, because four invariants have to survive a drag, a toggle, an
/// app update and a corrupted store alike:
///
/// 1. **The pinned section is always present, always visible, and always first.** The next-prayer
///    card is what Home is for; a layout that could hide it is a layout that can produce a screen
///    with nothing on it.
/// 2. **At least `minimumVisibleSections` sections stay visible.** The toggle that would drop
///    below the floor is refused *and* reported as refusable, so the editor can disable the
///    control rather than let the user tap into a silent no-op.
/// 3. **Loading reconciles rather than trusts.** A kind the stored array has never heard of is
///    appended in declaration order with its default visibility, and a stored raw value that no
///    longer maps to a case is dropped. That is what lets a later release add `hadithOfDay`
///    without a migration — the layout everybody already has simply grows a row.
/// 4. **`reset()` restores the default**, which is itself derived from `allCases` so it can never
///    fall behind the enum.
///
/// The whole value is stored as one encoded blob under a single `SettingsKey`. A key per section
/// would make rule 3 into a fan-out of reads and leave a half-written layout representable.
nonisolated struct HomeLayout: Equatable, Codable, Sendable {

    /// The order the stack is drawn in. `private(set)`: the invariants above are the reason this
    /// type exists, and a settable array would route around every one of them.
    private(set) var sections: [HomeSectionPreference]

    /// The order the shortcut circles are drawn in.
    private(set) var shortcuts: [HomeShortcutPreference]

    /// Below this, Home stops being a home screen and starts being a card on a background.
    static let minimumVisibleSections = 3

    /// A ceiling rather than a floor, and for the opposite reason: a wall of circles is not a
    /// shortcut to anything. Eight is two full rows on iPhone.
    static let maximumVisibleShortcuts = 8

    /// A fresh install, derived from the enums rather than listed out — so a case added to either
    /// one cannot be forgotten here.
    static let `default` = HomeLayout(
        sections: HomeSectionKind.allCases.map {
            HomeSectionPreference(kind: $0, isVisible: $0.defaultVisibility)
        },
        shortcuts: HomeShortcut.allCases.map {
            HomeShortcutPreference(shortcut: $0, isVisible: $0.defaultVisibility)
        }
    )

    /// Builds a layout that satisfies every invariant, from entries that may satisfy none.
    ///
    /// This is the only initializer, which is deliberate: there is no way to construct a
    /// `HomeLayout` that skips reconciliation, so a value read out of the store, built by a test,
    /// or assembled by hand all arrive in the same shape.
    init(sections: [HomeSectionPreference], shortcuts: [HomeShortcutPreference]) {
        self.sections = Self.reconciled(sections)
        self.shortcuts = Self.reconciled(shortcuts)
    }

    // MARK: Reading

    /// The sections Home actually draws, in order — visible, and backed by a feature that exists.
    var visibleSections: [HomeSectionKind] {
        sections.filter { $0.isVisible && $0.kind.isAvailable }.map(\.kind)
    }

    /// The shortcut circles Home actually draws, in order.
    var visibleShortcuts: [HomeShortcut] {
        shortcuts.filter { $0.isVisible && $0.shortcut.isAvailable }.map(\.shortcut)
    }

    /// The rows the customization screen shows. Unavailable kinds are filtered out entirely
    /// rather than shown disabled — a switch that turns on nothing is worse than no switch.
    var editableSections: [HomeSectionPreference] {
        sections.filter(\.kind.isAvailable)
    }

    var editableShortcuts: [HomeShortcutPreference] {
        shortcuts.filter(\.shortcut.isAvailable)
    }

    func isVisible(_ kind: HomeSectionKind) -> Bool {
        sections.first { $0.kind == kind }?.isVisible ?? false
    }

    func isVisible(_ shortcut: HomeShortcut) -> Bool {
        shortcuts.first { $0.shortcut == shortcut }?.isVisible ?? false
    }

    /// Whether the editor should let this section's toggle move at all.
    ///
    /// Asked *before* the tap, not discovered after it: the screen disables the control, so the
    /// floor is something the user can see rather than something they run into.
    func canChangeVisibility(of kind: HomeSectionKind) -> Bool {
        guard !kind.isPinned, kind.isAvailable else { return false }
        guard isVisible(kind) else { return true }
        return visibleSections.count > Self.minimumVisibleSections
    }

    /// The mirror image for shortcuts: hiding one is always allowed, showing one is capped.
    func canChangeVisibility(of shortcut: HomeShortcut) -> Bool {
        guard shortcut.isAvailable else { return false }
        guard !isVisible(shortcut) else { return true }
        return visibleShortcuts.count < Self.maximumVisibleShortcuts
    }

    // MARK: Editing

    mutating func setVisibility(_ newValue: Bool, of kind: HomeSectionKind) {
        guard let index = sections.firstIndex(where: { $0.kind == kind }),
              sections[index].isVisible != newValue,
              canChangeVisibility(of: kind) else { return }

        sections[index].isVisible = newValue
    }

    mutating func setVisibility(_ newValue: Bool, of shortcut: HomeShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.shortcut == shortcut }),
              shortcuts[index].isVisible != newValue,
              canChangeVisibility(of: shortcut) else { return }

        shortcuts[index].isVisible = newValue
    }

    /// Reorders the sections. **Offsets index `editableSections`**, which is the only list the
    /// user ever sees — the unavailable kinds are re-hung off the end afterwards, keeping their
    /// relative order, which is exactly where rule 3 would have appended them anyway.
    mutating func moveSections(from source: IndexSet, to destination: Int) {
        let editable = sections.filter(\.kind.isAvailable)
        let reserved = sections.filter { !$0.kind.isAvailable }

        sections = Self.moving(editable, from: source, to: destination) + reserved
        pinFirst()
    }

    /// The same, for the shortcut circles. Offsets index `editableShortcuts`.
    mutating func moveShortcuts(from source: IndexSet, to destination: Int) {
        let editable = shortcuts.filter(\.shortcut.isAvailable)
        let reserved = shortcuts.filter { !$0.shortcut.isAvailable }

        shortcuts = Self.moving(editable, from: source, to: destination) + reserved
    }

    mutating func reset() {
        self = .default
    }

    // MARK: Invariants

    /// Rule 1's enforcement point, applied after every reorder.
    ///
    /// The editor marks the pinned row undraggable, but `.moveDisabled(_:)` only stops that row
    /// being *picked up* — it does not stop another row being dropped above it. So the pin is
    /// re-asserted here rather than trusted to the view.
    private mutating func pinFirst() {
        guard let index = sections.firstIndex(where: { $0.kind.isPinned }), index != 0 else {
            return
        }
        sections.insert(sections.remove(at: index), at: 0)
    }

    /// Rules 1–3 for the sections, in one pass over whatever was stored.
    private static func reconciled(
        _ stored: [HomeSectionPreference]
    ) -> [HomeSectionPreference] {
        var seen: Set<HomeSectionKind> = []
        var result: [HomeSectionPreference] = []

        // A duplicate can only come from a corrupted store, and keeping the first is the one
        // choice that is stable across repeated loads.
        for preference in stored {
            guard seen.insert(preference.kind).inserted else { continue }
            result.append(preference)
        }

        for kind in HomeSectionKind.allCases where !seen.contains(kind) {
            result.append(HomeSectionPreference(kind: kind, isVisible: kind.defaultVisibility))
        }

        if let index = result.firstIndex(where: { $0.kind.isPinned }) {
            var pinned = result.remove(at: index)
            pinned.isVisible = true
            result.insert(pinned, at: 0)
        }

        // The floor, restored in declaration order. `setVisibility` will not let a user reach
        // this state, but a store written by an older build — or one where a kind has since been
        // withdrawn — can, and an empty Home is not an acceptable way to find that out.
        var visible = result.filter { $0.isVisible && $0.kind.isAvailable }.count

        for index in result.indices where visible < minimumVisibleSections {
            guard result[index].kind.isAvailable, !result[index].isVisible else { continue }
            result[index].isVisible = true
            visible += 1
        }

        return result
    }

    /// The same for shortcuts: dedupe, append what is missing, and enforce the ceiling.
    private static func reconciled(
        _ stored: [HomeShortcutPreference]
    ) -> [HomeShortcutPreference] {
        var seen: Set<HomeShortcut> = []
        var result: [HomeShortcutPreference] = []

        for preference in stored {
            guard seen.insert(preference.shortcut).inserted else { continue }
            result.append(preference)
        }

        for shortcut in HomeShortcut.allCases where !seen.contains(shortcut) {
            result.append(
                HomeShortcutPreference(shortcut: shortcut, isVisible: shortcut.defaultVisibility)
            )
        }

        var visible = 0

        for index in result.indices {
            guard result[index].isVisible, result[index].shortcut.isAvailable else { continue }
            visible += 1
            if visible > maximumVisibleShortcuts {
                result[index].isVisible = false
            }
        }

        return result
    }

    /// `onMove`'s semantics, implemented here rather than borrowed.
    ///
    /// SwiftUI ships `move(fromOffsets:toOffset:)`, but it ships it *in SwiftUI* — and Domain does
    /// not import that. Writing the twenty lines keeps the rule testable without a view, which is
    /// the trade this layer exists to make. `destination` is an index into the array as it was
    /// *before* the removal, which is the part that is easy to get wrong.
    private static func moving<Element>(
        _ items: [Element],
        from source: IndexSet,
        to destination: Int
    ) -> [Element] {
        let indices = source.sorted().filter { items.indices.contains($0) }
        guard !indices.isEmpty else { return items }

        let moved = indices.map { items[$0] }
        var result = items

        for index in indices.reversed() {
            result.remove(at: index)
        }

        let removedBefore = indices.filter { $0 < destination }.count
        let insertion = min(max(destination - removedBefore, 0), result.count)
        result.insert(contentsOf: moved, at: insertion)

        return result
    }

    // MARK: Storage

    /// The on-disk shape, and the reason `HomeLayout` decodes itself by hand.
    ///
    /// Rule 3 says an unrecognised raw value is *dropped from the array*. An element's own
    /// `Decodable` conformance cannot do that — a `HomeSectionKind` that fails to decode throws,
    /// and the throw takes the whole array with it, which would turn one stale string into a full
    /// reset of everybody's layout. So the raw strings are decoded as strings and mapped, and the
    /// preference types above deliberately do **not** conform to `Codable`: there is one way in,
    /// and it is the lenient one.
    private struct StoredSection: Codable {
        let kind: String
        let isVisible: Bool
    }

    private struct StoredShortcut: Codable {
        let shortcut: String
        let isVisible: Bool
    }

    private enum CodingKeys: String, CodingKey {
        case sections
        case shortcuts
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let storedSections = try container.decodeIfPresent(
            [StoredSection].self, forKey: .sections
        ) ?? []
        let storedShortcuts = try container.decodeIfPresent(
            [StoredShortcut].self, forKey: .shortcuts
        ) ?? []

        self.init(
            sections: storedSections.compactMap { stored in
                HomeSectionKind(rawValue: stored.kind).map {
                    HomeSectionPreference(kind: $0, isVisible: stored.isVisible)
                }
            },
            shortcuts: storedShortcuts.compactMap { stored in
                HomeShortcut(rawValue: stored.shortcut).map {
                    HomeShortcutPreference(shortcut: $0, isVisible: stored.isVisible)
                }
            }
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Everything is written, including the kinds that are not available yet — a choice the
        // user made about a section should survive the release that ships it.
        try container.encode(
            sections.map { StoredSection(kind: $0.kind.rawValue, isVisible: $0.isVisible) },
            forKey: .sections
        )
        try container.encode(
            shortcuts.map {
                StoredShortcut(shortcut: $0.shortcut.rawValue, isVisible: $0.isVisible)
            },
            forKey: .shortcuts
        )
    }
}
