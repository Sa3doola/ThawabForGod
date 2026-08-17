//
//  NamesGridView.swift
//  ThawabForGod
//

import SwiftUI
import TipKit

/// The ninety-nine names, as a grid that reflows to whatever it is given.
///
/// `.adaptive` rather than a column count branched on device: one rule fits a phone in portrait,
/// the same phone rotated, an iPad in a third of a Split View and a resized Mac window, and none
/// of those cases needs its own code. A `LazyVGrid` because ninety-nine cells is more than enough
/// for building them all up front to be visible.
struct NamesGridView: View {
    @Bindable var viewModel: NamesViewModel
    let coordinator: NamesCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// Minimum tile width. Sized so a phone in portrait gets three columns and everything wider
    /// gets more, while leaving room for the longest name — مَالِكُ الْمُلْكِ — to stay legible.
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        ScrollView {
            content
                .padding(20)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.namesTitle))
        .searchable(text: $viewModel.query, prompt: Text(l10n.string(.namesSearchPrompt)))
        // Re-runs on a language change, which re-fetches the meanings.
        .task(id: l10n.language) { await viewModel.load(in: l10n.language) }
        // Pushes into the stack Home owns rather than opening one of its own. Two-way: a back
        // swipe writes `nil` through the binding and the coordinator follows.
        .navigationDestination(item: openName) { name in
            NameDetail(name: name)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView(l10n.string(.namesLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready:
            if viewModel.matches.isEmpty {
                // Only reachable while searching — the corpus is never empty — so the message can
                // say so rather than hedging.
                InlineNotice(message: l10n.string(.namesNoMatches))
            } else {
                grid
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.namesUnavailable))
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.matches) { name in
                NameCell(name: name) {
                    viewModel.nameOpened()
                    coordinator.open(name)
                }
            }
        }
        // Anchored to the first cell rather than to the grid, so the popover points at a tile
        // instead of at the middle of the screen.
        .popoverTip(tapTip)
    }

    /// Rebuilt on each redraw so the copy follows a language change. Safe because the tip's
    /// identity is its fixed `id`, not the instance — see `NamesTips`.
    private var tapTip: NamesTapForMeaningTip {
        NamesTapForMeaningTip(
            titleText: l10n.string(.tipNamesTapTitle),
            messageText: l10n.string(.tipNamesTapMessage)
        )
    }

    /// Built here rather than reached for with `@Bindable`, because the coordinator exposes its
    /// selection read-only — so dismissal by swipe goes through the same method a Back button
    /// would call.
    private var openName: Binding<DivineName?> {
        Binding(
            get: { coordinator.openName },
            set: { if $0 == nil { coordinator.closeName() } }
        )
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        NamesGridView(
            viewModel: NamesViewModel(
                useCase: GetNamesUseCase(
                    repository: NamesRepository(database: CorpusDatabase(name: "corpus"))
                ),
                tips: NoNamesTipReporting()
            ),
            coordinator: NamesCoordinator()
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
