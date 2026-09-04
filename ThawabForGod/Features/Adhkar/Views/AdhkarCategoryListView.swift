//
//  AdhkarCategoryListView.swift
//  ThawabForGod
//

import SwiftUI

/// Hisn al-Muslim, by chapter.
///
/// **132 rows is the whole design problem.** The feature began with two — morning and evening —
/// where a plain stack of cards was the right answer and search would have been a control with
/// nothing to do. The bundled corpus is now the whole book, and a flat list of 132 headings is a
/// thing a reader scrolls past rather than reads: the dua for entering the market is in there,
/// and no amount of scrolling makes it findable.
///
/// So two ways in, and they are for different readers. **Groups** are for the reader who does not
/// know what they are looking for — twelve headings, each one a situation rather than a keyword,
/// which is how somebody arrives at "Travel" and finds three chapters they did not know existed.
/// **Search** is for the reader who does, and it matches either language's title so an English
/// interface still finds a chapter typed in Arabic.
///
/// The sections collapse, and start collapsed except the first. Twelve open sections is the flat
/// list again with headings in it; twelve closed ones is a table of contents, which is what a
/// reader who does not know the book needs to see first. `daily` is open because it holds the
/// chapter most of them came for.
struct AdhkarCategoryListView: View {
    @Bindable var viewModel: AdhkarViewModel
    let coordinator: AdhkarCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// Which groups are open. Local `@State` and not persisted: it is where the reader is looking
    /// right now, not a preference — and a stored one would have them return to a shape they set
    /// weeks ago and have to undo.
    @State private var expanded: Set<AdhkarGroup> = [.daily]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md, pinnedViews: .sectionHeaders) {
                content
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: AppBreakpoint.contentMeasure)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.adhkarTitle))
        // Pinned open on iOS rather than hidden until the reader pulls down: with 132 chapters
        // behind twelve collapsed headings, a search field nobody can see is the feature's main
        // way in, missing. `navigationBarDrawer` is iOS-only — the Mac puts the field in the
        // toolbar itself, where it is always visible anyway.
        #if os(iOS)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: l10n.string(.adhkarSearchPrompt)
        )
        #else
        .searchable(text: $viewModel.searchText, prompt: l10n.string(.adhkarSearchPrompt))
        #endif
        .task { await viewModel.loadCategories() }
        // Pushes into the stack this tab owns, rather than opening one of its own. Two-way: a
        // back swipe writes `nil` through the binding and the coordinator follows.
        .navigationDestination(item: openCategory) { categoryID in
            AdhkarReadingView(viewModel: viewModel, categoryID: categoryID)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.categoriesPhase {
        case .loading:
            // Labelled rather than a bare spinner: VoiceOver announces something other than
            // "in progress", and the label carries the language the reader chose.
            ProgressView(l10n.string(.adhkarLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .ready where !viewModel.hasSearchResults:
            InlineNotice(message: l10n.string(.adhkarNoResults))
                .padding(.top, AppSpacing.xxl)

        case .ready:
            ForEach(viewModel.sections) { section in
                Section {
                    if isOpen(section.group) {
                        ForEach(section.categories) { category in
                            CategoryRow(category: category) { coordinator.open(category) }
                        }
                    }
                } header: {
                    GroupHeader(
                        group: section.group,
                        count: section.categories.count,
                        isOpen: isOpen(section.group),
                        action: { toggle(section.group) }
                    )
                }
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.adhkarUnavailable))
        }
    }

    /// Where the text comes from, said once for the whole book.
    ///
    /// It used to be a citation on every dhikr, because the old 34-row corpus carried one. Hisn
    /// al-Muslim's own text does not, so the attribution moved up to where it is actually true —
    /// and the verification warning stays with it, because the corpus is still third-party data
    /// nobody has read line by line. See `Resources/Corpus/README.md`.
    private var attribution: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(l10n.string(.adhkarSourceAttribution))
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(theme.textSecondary)

            Text(l10n.string(.adhkarVerificationNotice))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(theme.warning.opacity(0.12), in: .rect(cornerRadius: AppRadius.md))
        .padding(.top, AppSpacing.sm)
    }

    /// A search opens everything: a heading the reader has to tap before seeing whether their
    /// query matched anything under it is a search that answers in two steps.
    private func isOpen(_ group: AdhkarGroup) -> Bool {
        viewModel.isSearching || expanded.contains(group)
    }

    private func toggle(_ group: AdhkarGroup) {
        withAnimation(.snappy) {
            if expanded.contains(group) {
                expanded.remove(group)
            } else {
                expanded.insert(group)
            }
        }
    }

    /// Built here rather than reached for with `@Bindable`, because the coordinator exposes its
    /// selection read-only — so dismissal by swipe goes through the same method a Back button
    /// would call.
    private var openCategory: Binding<String?> {
        Binding(
            get: { coordinator.openCategoryID },
            set: { if $0 == nil { coordinator.closeCategory() } }
        )
    }
}

/// One of the twelve headings, and the control that opens it.
///
/// It carries the number of chapters under it because a closed section is otherwise a promise
/// with no size — "Travel" could be one chapter or thirty, and the reader deciding whether to
/// open it is deciding whether to spend a scroll.
private struct GroupHeader: View {
    let group: AdhkarGroup
    let count: Int
    let isOpen: Bool
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: group.symbolName)
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .frame(width: 22)

                Text(l10n.string(group.titleKey))
                    .appFont(.headline)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: AppSpacing.sm)

                Text(l10n.string(count, grouped: false))
                    .appFont(.footnote, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)

                // Rotated rather than swapped for `chevron.up`, so the two states are one shape
                // moving and the reader's eye can follow it. `.forward` mirrors for Arabic on its
                // own, which is why the closed state points along the reading direction.
                Image(systemName: "chevron.forward")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.md)
            .frame(maxWidth: .infinity)
            // Opaque, because the header pins while its rows scroll under it.
            .background(theme.background)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        AdhkarCategoryListView(
            viewModel: AdhkarViewModel(
                useCase: GetAdhkarUseCase(
                    repository: AdhkarRepository(database: CorpusDatabase(name: "corpus"))
                )
            ),
            coordinator: AdhkarCoordinator()
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
