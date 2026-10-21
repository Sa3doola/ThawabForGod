//
//  QuranLibraryHeader.swift
//  ThawabForGod
//

import SwiftUI

/// The Library's pinned header: one field that goes to an address and filters the surahs, the line
/// under it that teaches or refuses, and the picker over the indexes.
///
/// Pinned rather than the list's first row, because the four indexes are four scroll views and a
/// field living inside one would lose its focus and its text every time the tab changed. Held to
/// the reading measure and centred, so on a wide window it lines up with the lists below it.
struct QuranLibraryHeader: View {
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            fieldRow
            hintOrFailure
            picker
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: AppBreakpoint.readingMeasure)
        .frame(maxWidth: .infinity)
        .onChange(of: coordinator.goToFocusRequest) { isFocused = true }
        .onChange(of: viewModel.failure) {
            if viewModel.failure != nil {
                AccessibilityNotification.Announcement(failureMessage).post()
            }
        }
    }

    // MARK: Field

    private var fieldRow: some View {
        @Bindable var viewModel = viewModel
        return HStack(spacing: AppSpacing.sm) {
            TextField(text: $viewModel.query) {
                Text(placeholder)
            }
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit(submit)
            // Explicit: on the Mac the field's label shows only as a placeholder, and the audit found
            // the field with no description (M8).
            .accessibilityLabel(Text(placeholder))
            .accessibilityIdentifier("quran.library.query")
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(l10n.string(.quranClear)))
                .accessibilityIdentifier("quran.library.clear")
                Button(action: submit) {
                    Text(l10n.string(.quranGo))
                }
                .disabled(!viewModel.canSubmit)
                .accessibilityIdentifier("quran.library.go")
            }
        }
    }

    private var placeholder: String {
        viewModel.showsPages
            ? l10n.string(.quranFieldPlaceholderPages)
            : l10n.string(.quranFieldPlaceholderSurahs)
    }

    private func submit() {
        if let target = viewModel.submit() {
            isFocused = false
            coordinator.open(target)
        } else {
            // Return dismisses the keyboard just after this runs, so a refusal re-focuses on the next
            // turn; set now, it would land before the field loses focus and change nothing.
            Task { @MainActor in isFocused = true }
        }
    }

    // MARK: Hint and failure

    @ViewBuilder
    private var hintOrFailure: some View {
        if viewModel.failure != nil {
            Text(failureMessage)
                .appFont(.footnote)
                .foregroundStyle(theme.danger)
                .accessibilityIdentifier("quran.library.error")
        } else if let suggestion = viewModel.textSearchSuggestion {
            Button {
                isFocused = false
                coordinator.showSearch(prefill: suggestion)
                viewModel.didOpen()
            } label: {
                // The query is isolated (FSI ... PDI) so an English interface does not reorder it.
                Text(l10n.string(.quranSearchInAyahs, "\u{2068}\(suggestion)\u{2069}"))
                    .appFont(.footnote)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)
            .accessibilityIdentifier("quran.library.searchAyahs")
        } else {
            Text(exampleLine)
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .accessibilityIdentifier("quran.library.hint")
        }
    }

    /// "2:255" is built here and passed as one argument, so the surah, the colon and the ayah stay
    /// together as a single piece of the format string rather than being three substitutions
    /// that the format could place apart. Nothing is bidi-isolated here: the line orders
    /// correctly in both digit systems because of how the format string itself is written. Where there are no pages the first
    /// example is a surah number, because there a bare number is one.
    private var exampleLine: String {
        let first = l10n.string(viewModel.showsPages ? 50 : 18, grouped: false)
        let reference = "\(l10n.string(2, grouped: false)):\(l10n.string(255, grouped: false))"
        return l10n.string(
            .quranExample,
            first, reference, l10n.string(5, grouped: false), l10n.string(12, grouped: false)
        )
    }

    private var failureMessage: String {
        switch viewModel.failure {
        case .pagesUnavailable:
            l10n.string(.quranPagesUnavailable)
        case .notFound, nil:
            viewModel.showsPages
                ? l10n.string(.quranNotFoundPages)
                : l10n.string(.quranNotFoundSurahs)
        }
    }

    // MARK: Picker

    @ViewBuilder
    private var picker: some View {
        @Bindable var viewModel = viewModel
        let tabs = Picker(selection: $viewModel.tab) {
            ForEach(viewModel.visibleTabs) { tab in
                Text(title(of: tab)).tag(tab)
            }
        } label: {
            Text(l10n.string(.quranIndex))
        }
        .labelsHidden()
        .accessibilityIdentifier("quran.library.tabs")
        // Four segments cannot hold their labels at an accessibility size.
        if dynamicTypeSize.isAccessibilitySize {
            tabs.pickerStyle(.menu)
        } else {
            tabs.pickerStyle(.segmented)
        }
    }

    private func title(of tab: QuranLibraryTab) -> String {
        switch tab {
        case .surah: l10n.string(.quranTabSurah)
        case .juz: l10n.string(.quranTabJuz)
        case .hizb: l10n.string(.quranTabHizb)
        case .page: l10n.string(.quranTabPage)
        }
    }
}
