//
//  QuranLibraryRows.swift
//  ThawabForGod
//

import SwiftUI

// The rows of the Library's four indexes and the Continue reading row. They are labels only: the
// lists wrap them in `Button`s, which is what lets one row type serve a tap, a swipe and a
// context menu without each deciding what it opens.
//
// Every page number on this screen is drawn only when the row model carries one. The row models
// are built by `QuranLibraryIndex`, which drops a page in a build that has none, so nothing here
// asks which build it is.

/// A surah: its number, its name in the interface language, where it was revealed and how long it
/// is, with the calligraphic name and the start page trailing.
struct QuranLibrarySurahRowView: View {
    let row: QuranLibrarySurahRow

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.quranFaces) private var faces
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout(spacing: AppSpacing.md))
        return layout {
            Text(l10n.string(row.surah.number, grouped: false))
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(theme.accent)
                .frame(minWidth: 32, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            detail
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// The name block and the trailing column. At an accessibility size everything stacks (number,
    /// names, details), since beside the number the name would be left a few characters wide and
    /// its words would break mid-word.
    private var detail: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout(spacing: AppSpacing.sm))
        return layout {
            names
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: AppSpacing.sm)
            }
            trailing
        }
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: row.surah.name(in: l10n.language))
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)
            detailsLine
                .appFont(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    /// Place and length. Beside each other normally; one per line at an accessibility size, each
    /// kept whole so a word is never split to fit.
    private var detailsLine: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: AppSpacing.xs))
        return layout {
            Text(row.surah.revelationPlace == .makkah ? l10n.string(.quranMeccan) : l10n.string(.quranMedinan))
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize {
                Text(verbatim: "·")
                    .accessibilityHidden(true)
            }
            Text(l10n.string(.quranAyahsLabel, l10n.string(row.surah.ayahCount, grouped: false)))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The glyph is left out only where it would say the same word twice: beside an Arabic name in a
    /// build without the QUL face, where it falls back to that Arabic name.
    private var showsGlyph: Bool {
        faces.contains(.surahName) || l10n.language != .arabic
    }

    private var trailing: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            if showsGlyph {
                SurahNameGlyph(surah: row.surah, name: row.surah.arabicName, size: 30)
                    .accessibilityHidden(true)
            }
            if let page = row.startPage {
                QuranLibraryPageLabel(page: page)
            }
        }
    }
}

/// A juz, a hizb or one of a hizb's quarters, with the ayah it starts at.
struct QuranLibraryStartRowView: View {
    let row: QuranLibraryStartRow

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout())
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.title(row, l10n: l10n))
                    .appFont(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(verbatim: QuranLibraryReference.string(surah: row.surah, ayah: row.ayah, l10n: l10n))
                    .appFont(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: AppSpacing.sm)
            }
            if let page = row.page {
                QuranLibraryPageLabel(page: page)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// The same words the page margins carry, so a division is called one thing everywhere.
    static func title(_ row: QuranLibraryStartRow, l10n: LocalizationManager) -> String {
        let number = l10n.string(row.number, grouped: false)
        switch row.kind {
        case .juz: return l10n.string(.quranJuzNumber, number)
        case .hizb: return l10n.string(.quranMarginHizb, number)
        case .quarter(1): return l10n.string(.quranMarginQuarterHizb, number)
        case .quarter(2): return l10n.string(.quranMarginHalfHizb, number)
        case .quarter: return l10n.string(.quranMarginThreeQuarterHizb, number)
        }
    }
}

/// One cell of the Page grid: the page number and the surah its first ayah belongs to.
struct QuranLibraryPageCellView: View {
    let cell: QuranLibraryPageCell
    let isCurrent: Bool

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(l10n.string(cell.number, grouped: false))
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
            Text(verbatim: cell.surah?.name(in: l10n.language) ?? "")
                .appFont(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, AppSpacing.xs)
        .background(isCurrent ? theme.accent.opacity(0.25) : theme.surface, in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

/// Where the reader was, and a tap to go back to it. Its text comes from the values it is given
/// and nothing live, so it cannot track the reader's page turns (`QuranLibraryContent` explains
/// why that matters). Drawn by `QuranLibraryContinueBar`.
struct QuranContinueReadingRow: View {
    let resume: QuranLibraryResume
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout())
        return Button(action: action) {
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.string(.quranContinueReading))
                        .appFont(.headline)
                        .foregroundStyle(theme.accent)
                    Text(verbatim: QuranLibraryReference.string(surah: resume.surah, ayah: resume.ayah, l10n: l10n))
                        .appFont(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: AppSpacing.sm)
                }
                if let page = resume.page {
                    QuranLibraryPageLabel(page: page)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }
}

/// Continue reading, pinned under the Library's header.
///
/// Pinned rather than the first row of each index: a reader who scrolls to a surah, opens it and
/// comes back finds the list where they left it, with a first row scrolled out of sight, and the
/// Page grid scrolls itself to the current page, so a row above it is almost never on screen. The
/// row exists to give the reader a way back, so it is not left to be hidden. Held to the same
/// measure and side padding as the header, and as tall as a list row.
struct QuranLibraryContinueBar: View {
    let resume: QuranLibraryResume
    let viewModel: QuranLibraryViewModel
    let coordinator: QuranCoordinator

    @Environment(\.theme) private var theme

    var body: some View {
        QuranContinueReadingRow(resume: resume) {
            viewModel.didOpen()
            coordinator.openReader()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(theme.surface, in: .rect(cornerRadius: AppRadius.md))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.sm)
        .frame(maxWidth: AppBreakpoint.readingMeasure)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("quran.library.continue")
    }
}

/// "Page 293", for a row whose model carries a page.
private struct QuranLibraryPageLabel: View {
    let page: Int

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Text(l10n.string(.quranPageNumber, l10n.string(page, grouped: false)))
            .appFont(.caption)
            .foregroundStyle(theme.textSecondary)
    }
}

/// A surah's name followed by `s:a`.
private enum QuranLibraryReference {
    /// One string, so the colon between the numbers cannot be reordered around them: the numbers
    /// are formatted first and the whole is drawn as a single `Text`.
    @MainActor
    static func string(surah: Surah, ayah: VerseReference, l10n: LocalizationManager) -> String {
        let numbers = "\(l10n.string(ayah.surah, grouped: false)):\(l10n.string(ayah.verse, grouped: false))"
        return "\(surah.name(in: l10n.language)) \(numbers)"
    }
}
