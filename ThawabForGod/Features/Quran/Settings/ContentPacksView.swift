//
//  ContentPacksView.swift
//  ThawabForGod
//

import SwiftUI

/// Translations & Tafsir: every bundled pack, enabled or not, in the order the ayah panel and
/// separated verses show them, and the default tafsir. Mushaf's `ContentPacksView`. Everything ships
/// in the app, so there is nothing to download or delete.
struct ContentPacksView: View {
    let viewModel: QuranSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        List {
            if let translations = viewModel.translationSelection {
                translationsSection(translations)
            }
            if let tafsirs = viewModel.tafsirSelection, !tafsirs.rows.isEmpty {
                tafsirSection(tafsirs)
                defaultTafsirSection(tafsirs)
            }
        }
        .navigationTitle(Text(l10n.string(.quranPacksTitle)))
        .toolbarTitleDisplayMode(.inline)
        .quranPacksEditButton()
        .task { await viewModel.load() }
        .accessibilityIdentifier("quran.packs.list")
    }

    private func translationsSection(_ selection: ContentPackSelection) -> some View {
        Section {
            ForEach(selection.rows) { row in
                PackRow(row: row) { viewModel.setTranslation(row.id, enabled: $0) }
            }
            .onMove { viewModel.moveTranslations(fromOffsets: $0, toOffset: $1) }
        } header: {
            Text(l10n.string(.quranPacksTranslations))
        } footer: {
            Text(l10n.string(.quranPacksTranslationsFooter))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tafsirSection(_ selection: ContentPackSelection) -> some View {
        Section {
            ForEach(selection.rows) { row in
                PackRow(row: row) { viewModel.setTafsir(row.id, enabled: $0) }
            }
            .onMove { viewModel.moveTafsirs(fromOffsets: $0, toOffset: $1) }
        } header: {
            Text(l10n.string(.quranPacksTafsir))
        } footer: {
            Text(l10n.string(.quranPacksTafsirFooter))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func defaultTafsirSection(_ selection: ContentPackSelection) -> some View {
        Section {
            Picker(selection: Binding(
                get: { viewModel.defaultTafsir },
                set: { viewModel.setDefaultTafsir($0) }
            )) {
                Text(l10n.string(.quranPacksAutomatic)).tag(ContentPackID?.none)
                ForEach(selection.rows.filter(\.isEnabled)) { row in
                    Text(verbatim: row.pack.name(in: l10n.language)).tag(ContentPackID?.some(row.id))
                }
            } label: {
                Text(l10n.string(.quranPacksDefaultTafsir))
            }
            .accessibilityIdentifier("quran.packs.defaultTafsir")
        } footer: {
            Text(l10n.string(.quranPacksDefaultTafsirFooter))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PackRow: View {
    let row: ContentPackSelection.Row
    let onToggle: @MainActor (Bool) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.locale) private var locale
    @Environment(\.theme) private var theme

    var body: some View {
        Toggle(isOn: Binding(get: { row.isEnabled }, set: { onToggle($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.pack.name(in: l10n.language))
                    .appFont(.body)
                    .foregroundStyle(theme.textPrimary)
                Text(verbatim: subtitle)
                    .appFont(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .accessibilityIdentifier("quran.packs.row.\(row.id.rawValue)")
    }

    private var subtitle: String {
        [locale.localizedString(forLanguageCode: row.pack.language) ?? row.pack.language, row.pack.author(in: l10n.language)]
            .joined(separator: " · ")
    }
}
