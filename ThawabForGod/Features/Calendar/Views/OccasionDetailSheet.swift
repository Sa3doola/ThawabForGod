//
//  OccasionDetailSheet.swift
//  ThawabForGod
//

import SwiftUI

/// What the sheet is about: an occasion and, when it is known, the days it falls on.
struct OccasionSheetItem: Identifiable {
    let occasion: IslamicOccasion
    let dateLine: String?

    var id: String { occasion.id }
}

/// An occasion in full: what it is, its virtue where one is sourced, the sources with their
/// gradings, and where scholars differ.
///
/// Every line here is text the catalogue carries for the occasion — nothing is composed. A virtue
/// is shown only if the occasion has one, and always with its sources beneath it.
struct OccasionDetailSheet: View {
    let item: OccasionSheetItem

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let summary = item.occasion.summaryKey {
                        Text(l10n.string(summary))
                            .appFont(.body)
                            .foregroundStyle(theme.textPrimary)
                    }

                    if let note = item.occasion.noteKey {
                        Text(l10n.string(note))
                            .appFont(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }

                    if let virtue = item.occasion.virtueKey {
                        section(.occasionDetailVirtue) {
                            Text(l10n.string(virtue))
                                .appFont(.body)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }

                    if !item.occasion.sources.isEmpty {
                        section(.occasionDetailSources) {
                            ForEach(Array(item.occasion.sources.enumerated()), id: \.offset) { _, source in
                                Text(sourceLine(source))
                                    .appFont(.footnote)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }

                    if let scholarly = item.occasion.scholarlyNoteKey {
                        section(.occasionDetailScholarlyNote) {
                            Text(l10n.string(scholarly))
                                .appFont(.subheadline)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.background)
            .navigationTitle(l10n.string(item.occasion.nameKey))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.calendarDone)) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.occasion.category.tint(in: theme))
                .frame(width: 10, height: 10)
            Text(l10n.string(item.occasion.category.labelKey))
                .appFont(.footnote, weight: .medium)
                .foregroundStyle(theme.textSecondary)
            if let line = item.dateLine {
                Text("·").foregroundStyle(theme.textSecondary)
                Text(line)
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func section<Content: View>(_ title: L10nKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(title))
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    /// `Sahih Muslim 2746 — Sahih`.
    private func sourceLine(_ source: OccasionSource) -> String {
        let cited = l10n.string(.occasionSourceLine, l10n.string(source.work.labelKey), source.reference)
        guard let grading = source.grading else { return cited }
        return l10n.string(.occasionSourceGraded, cited, l10n.string(grading.labelKey))
    }
}
