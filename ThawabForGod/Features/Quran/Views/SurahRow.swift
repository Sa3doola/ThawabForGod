//
//  SurahRow.swift
//  ThawabForGod
//

import SwiftUI

/// One chapter, as a row on a phone and as a cell on a board.
///
/// A `Button` rather than a tappable `VStack`, like every other tappable thing in the app — it
/// buys the pressed state, the VoiceOver trait and keyboard focus without any of them being
/// rebuilt by hand.
///
/// **The same cell, unwrapped.** The design's iPad grid is not a second design: it is these four
/// pieces — the number, the two names, what it is and how long — turned from a line into a block.
/// So there is one view with two arrangements rather than a `SurahCell` beside a `SurahRow`,
/// which would be two things to keep in step and one of them always a version behind.
///
/// The arrangement is passed in rather than measured here. The list already knows the width it is
/// laying out for, and a row that measured itself would have to do it 114 times to reach the same
/// answer the grid above it worked out once.
struct SurahRow: View {
    /// Which way round the four pieces go.
    enum Layout {
        /// One line: number, names, then what it is on the trailing edge.
        case row
        /// A block: number and kind on one line, the names under them, the length last. What a
        /// 200-point column can hold without either name shrinking.
        case cell
    }

    let surah: Surah
    var layout: Layout = .row
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            content
                .padding(AppSpacing.row)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
                .appHover()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch layout {
        case .row:
            HStack(spacing: AppSpacing.md) {
                number
                names
                Spacer(minLength: AppSpacing.sm)
                detail
            }

        case .cell:
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    number
                    Spacer(minLength: AppSpacing.xs)
                    place
                }

                names

                verses
            }
        }
    }

    /// Its place in the mushaf, which is how most readers refer to a chapter.
    private var number: some View {
        Text(l10n.string(surah.id, grouped: false))
            .appFont(.footnote, weight: .semibold)
            .foregroundStyle(theme.accent)
            .frame(width: 34, height: 34)
            .background(theme.accent.opacity(0.12), in: .circle)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Arabic whatever the interface language is, so VoiceOver is told which language to
            // read it in. A name is one word, so unlike a verse it needs no paragraph direction
            // pinned — the bidi algorithm places it correctly on either screen.
            Text(surah.arabicName)
                .appFont(.title3)
                .foregroundStyle(theme.textPrimary)
                .environment(\.locale, AppLanguage.arabic.locale)

            Text(l10n.language == .arabic ? surah.transliteration : surah.englishName)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var detail: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            place
            verses
        }
    }

    /// Meccan or Medinan, as a chip.
    private var place: some View {
        Text(l10n.string(surah.revelationPlace == .meccan ? .quranMeccan : .quranMedinan))
            .appFont(.caption, weight: .medium)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 3)
            .background(theme.separator.opacity(0.35), in: .capsule)
    }

    private var verses: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(l10n.string(.quranVersesLabel))
            Text(l10n.string(surah.verseCount, grouped: false))
        }
        .appFont(.caption)
        .foregroundStyle(theme.textSecondary)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    SurahRow(
        surah: Surah(
            id: 2,
            arabicName: "البقرة",
            transliteration: "Al-Baqara",
            englishName: "The Cow",
            verseCount: 286,
            revelationPlace: .medinan,
            revelationOrder: 87,
            bismillah: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
        ),
        action: {}
    )
    .padding()
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
