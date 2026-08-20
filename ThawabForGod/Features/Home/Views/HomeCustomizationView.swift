//
//  HomeCustomizationView.swift
//  ThawabForGod
//

import SwiftUI

/// Where Home is arranged: two lists, each row draggable and switchable, and nothing to submit.
///
/// **There is no Edit button**, because there is nothing on this screen *except* editing — a mode
/// toggle would be a step between the user and the only thing the screen does.
///
/// It does not hold `editMode` active either, and that was tried first: it is what puts the drag
/// handles on the rows, and it also makes every control *in* those rows stop responding. A screen
/// whose switches do not switch is a worse trade than one whose reordering is a touch-and-hold —
/// which is what `onMove` gives on its own, on both platforms, with the toggles still live. The
/// footer says so, since a gesture with no handle beside it has to be told.
///
/// The pinned row is present, locked and disabled rather than absent. A user who cannot find the
/// next-prayer card in this list would reasonably conclude the screen is broken; a lock says the
/// decision was made for them and why.
struct HomeCustomizationView: View {
    let viewModel: HomeCustomizationViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(viewModel.sections) { preference in
                    SectionRow(viewModel: viewModel, preference: preference)
                }
                .onMove(perform: viewModel.moveSections)
            } header: {
                Text(l10n.string(.homeCustomizeSectionsHeader))
            } footer: {
                Text(l10n.string(.homeCustomizeSectionsFooter))
            }

            Section(l10n.string(.homeSectionShortcuts)) {
                ForEach(viewModel.shortcuts) { preference in
                    ShortcutRow(viewModel: viewModel, preference: preference)
                }
                .onMove(perform: viewModel.moveShortcuts)
            }
        }
        .navigationTitle(l10n.string(.homeCustomizeTitle))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(l10n.string(.homeCustomizeReset)) {
                    viewModel.isConfirmingReset = true
                }
            }
        }
        .confirmationDialog(
            l10n.string(.homeCustomizeResetConfirm),
            isPresented: Bindable(viewModel).isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button(l10n.string(.homeCustomizeReset), role: .destructive) {
                viewModel.reset()
            }
        }
        // Re-read on each appearance: Settings and Home both push this screen, and the other one
        // may have been used in between.
        .onAppear { viewModel.reload() }
        // Nothing is submitted, so nothing may be left in the air — see `flush()`.
        .onDisappear { viewModel.flush() }
    }
}

/// One section's row: symbol, name, and a switch — or a lock, for the one that cannot move.
private struct SectionRow: View {
    let viewModel: HomeCustomizationViewModel
    let preference: HomeSectionPreference

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        RowLabel(
            symbol: preference.kind.symbol,
            title: l10n.string(preference.kind.labelKey),
            isPinned: preference.kind.isPinned,
            isVisible: preference.isVisible,
            canToggle: viewModel.canToggle(preference.kind),
            setVisible: { viewModel.setVisibility($0, of: preference.kind) }
        )
        // The pin, asserted in the list as well as in the model: `moveDisabled` stops this row
        // being picked up, and `HomeLayout` puts it back if something is dropped above it.
        .moveDisabled(preference.kind.isPinned)
        .accessibilityActions {
            if !preference.kind.isPinned {
                Button(l10n.string(.reorderMoveUp)) { viewModel.move(preference.kind, by: -1) }
                Button(l10n.string(.reorderMoveDown)) { viewModel.move(preference.kind, by: 1) }
            }
        }
    }
}

/// One shortcut's row. The same shape, minus the pin — no shortcut is compulsory.
private struct ShortcutRow: View {
    let viewModel: HomeCustomizationViewModel
    let preference: HomeShortcutPreference

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        RowLabel(
            symbol: preference.shortcut.symbol,
            title: l10n.string(preference.shortcut.labelKey),
            isPinned: false,
            isVisible: preference.isVisible,
            canToggle: viewModel.canToggle(preference.shortcut),
            setVisible: { viewModel.setVisibility($0, of: preference.shortcut) }
        )
        .accessibilityActions {
            Button(l10n.string(.reorderMoveUp)) { viewModel.move(preference.shortcut, by: -1) }
            Button(l10n.string(.reorderMoveDown)) { viewModel.move(preference.shortcut, by: 1) }
        }
    }
}

/// The row itself, shared by both lists.
///
/// A `Toggle` rather than a tappable checkmark: it is the control VoiceOver already knows how to
/// describe, it carries its own disabled appearance for the pinned row and the three-section
/// floor, and it cannot be mistaken for a selection tick in a list that also reorders.
private struct RowLabel: View {
    let symbol: String
    let title: String
    let isPinned: Bool
    let isVisible: Bool
    let canToggle: Bool

    /// `@MainActor @Sendable` because that is what `Binding`'s setter now asks for: it may be
    /// called from an isolated context, so a plain closure would be a value crossing a boundary
    /// unchecked. Everything the call sites capture — the view model and a `Sendable`
    /// preference — already satisfies it.
    let setVisible: @MainActor @Sendable (Bool) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Toggle(isOn: binding) {
            Label {
                Text(title)
                    .appFont(.body)
                    .foregroundStyle(theme.textPrimary)
            } icon: {
                Image(systemName: isPinned ? "lock" : symbol)
                    .foregroundStyle(isPinned ? theme.textSecondary : theme.accent)
            }
        }
        .tint(theme.accent)
        .disabled(!canToggle)
    }

    /// Built here rather than bound to the model, because the value being shown belongs to the
    /// layout and the write has to go through the rules that guard it.
    private var binding: Binding<Bool> {
        Binding(get: { isVisible }, set: setVisible)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()
    let repository = HomeLayoutRepository(settingsStore: settingsStore)

    NavigationStack {
        HomeCustomizationView(
            viewModel: HomeCustomizationViewModel(
                getLayout: GetHomeLayoutUseCase(repository: repository),
                updateLayout: UpdateHomeLayoutUseCase(repository: repository),
                resetLayout: ResetHomeLayoutUseCase(repository: repository)
            )
        )
    }
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
