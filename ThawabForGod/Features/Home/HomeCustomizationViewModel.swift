//
//  HomeCustomizationViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the screen where Home is arranged.
///
/// It holds the layout and forwards every edit to it, which is deliberate: `HomeLayout` is where
/// the rules live — the pinned section, the three-section floor, the shortcut ceiling — and a
/// view model that reimplemented any of them would be a second opinion waiting to disagree with
/// the first. Everything here is a one-line delegation plus a save.
///
/// **There is no Save button.** Every change is persisted, matching the reading-customization
/// panel in the Quran: a screen whose whole purpose is arranging things should show the
/// arrangement, not a form to be submitted. The write is debounced so a burst of taps — or a drag
/// that reports more than once — collapses into one, and flushed on the way out so nothing is
/// left in the air.
@Observable
@MainActor
final class HomeCustomizationViewModel {

    private(set) var layout: HomeLayout

    /// Whether the reset confirmation is up. On the view model rather than as `@State` for the
    /// reason `QuranCoordinator` holds its panel flag: it survives a redraw, and a destructive
    /// action's confirmation is not something a scroll should be able to dismiss.
    var isConfirmingReset = false

    @ObservationIgnored private let getLayout: GetHomeLayoutUseCase
    @ObservationIgnored private let updateLayout: UpdateHomeLayoutUseCase
    @ObservationIgnored private let resetLayout: ResetHomeLayoutUseCase

    /// Called after every write, so the Home screen behind this one re-reads and follows along.
    @ObservationIgnored private let onChange: () -> Void

    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(
        getLayout: GetHomeLayoutUseCase,
        updateLayout: UpdateHomeLayoutUseCase,
        resetLayout: ResetHomeLayoutUseCase,
        onChange: @escaping () -> Void = {}
    ) {
        self.getLayout = getLayout
        self.updateLayout = updateLayout
        self.resetLayout = resetLayout
        self.onChange = onChange
        self.layout = getLayout()
    }

    /// Re-reads the stored arrangement, for each appearance of the screen.
    func reload() {
        layout = getLayout()
    }

    // MARK: What the rows show

    /// The section rows, in order — unavailable kinds filtered out entirely rather than shown
    /// disabled, because a switch that turns on nothing is worse than no switch.
    var sections: [HomeSectionPreference] { layout.editableSections }

    var shortcuts: [HomeShortcutPreference] { layout.editableShortcuts }

    /// Whether a row's toggle is live. Asked before the tap so the control is *disabled* at the
    /// three-section floor rather than silently refusing when it is reached.
    func canToggle(_ kind: HomeSectionKind) -> Bool {
        layout.canChangeVisibility(of: kind)
    }

    func canToggle(_ shortcut: HomeShortcut) -> Bool {
        layout.canChangeVisibility(of: shortcut)
    }

    // MARK: Editing

    func setVisibility(_ isVisible: Bool, of kind: HomeSectionKind) {
        layout.setVisibility(isVisible, of: kind)
        scheduleSave()
    }

    func setVisibility(_ isVisible: Bool, of shortcut: HomeShortcut) {
        layout.setVisibility(isVisible, of: shortcut)
        scheduleSave()
    }

    func moveSections(from source: IndexSet, to destination: Int) {
        layout.moveSections(from: source, to: destination)
        scheduleSave()
    }

    func moveShortcuts(from source: IndexSet, to destination: Int) {
        layout.moveShortcuts(from: source, to: destination)
        scheduleSave()
    }

    /// Moves a section by one place, for the accessibility actions on its row.
    ///
    /// Drag handles are not reachable by VoiceOver or by a switch control, so reordering has to
    /// be available as a plain action too. It is expressed in terms of `moveSections` rather than
    /// beside it, so the pin and everything else it enforces apply here unchanged.
    func move(_ kind: HomeSectionKind, by offset: Int) {
        guard let index = sections.firstIndex(where: { $0.kind == kind }) else { return }

        let destination = index + offset
        guard sections.indices.contains(destination) else { return }

        // `onMove`'s destination is an index in the array *before* the removal, so moving down
        // by one is a destination of `index + 2`, not `index + 1`.
        moveSections(from: IndexSet(integer: index), to: offset > 0 ? destination + 1 : destination)
    }

    func move(_ shortcut: HomeShortcut, by offset: Int) {
        guard let index = shortcuts.firstIndex(where: { $0.shortcut == shortcut }) else { return }

        let destination = index + offset
        guard shortcuts.indices.contains(destination) else { return }

        moveShortcuts(
            from: IndexSet(integer: index),
            to: offset > 0 ? destination + 1 : destination
        )
    }

    /// Back to the arrangement the app shipped with.
    ///
    /// Straight to the store rather than through the debounce: a reset is deliberate and
    /// confirmed, and there is nothing to coalesce it with.
    func reset() {
        saveTask?.cancel()
        saveTask = nil
        layout = resetLayout()
        onChange()
    }

    // MARK: Persisting

    /// Writes shortly, replacing any write already waiting.
    ///
    /// The delay is what keeps a run of taps from becoming a run of encodes. `onChange` fires
    /// with the write rather than with the edit, so the screen behind never reads a value that
    /// has not been stored yet.
    private func scheduleSave() {
        saveTask?.cancel()

        let pending = layout
        saveTask = Task { [updateLayout, onChange] in
            guard (try? await Task.sleep(for: .milliseconds(250))) != nil else { return }

            updateLayout(pending)
            onChange()
        }
    }

    /// Writes anything still waiting, immediately.
    ///
    /// Driven from the screen's `onDisappear`. Without it, arranging Home and leaving inside the
    /// debounce window would lose the last change — the one failure a screen with no Save button
    /// absolutely cannot have.
    func flush() {
        guard saveTask != nil else { return }

        saveTask?.cancel()
        saveTask = nil
        updateLayout(layout)
        onChange()
    }
}
