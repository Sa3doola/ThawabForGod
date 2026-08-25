//
//  ContinueReadingCard.swift
//  ThawabForGod
//

import SwiftUI

/// The way back into the text, above the lists.
///
/// Above the segmented control rather than inside one of its segments, because it is not a way of
/// *choosing* where to start — it is the answer to the question the reader most often opens this
/// tab with, and it belongs before the choice rather than behind it.
///
/// It is absent, not disabled, before anything has been read. A control that says "continue" when
/// there is nothing to continue is worse than no control.
///
/// **Its shape says what it is.** A ruled page on the leading edge, the place in the middle over
/// a rail for how far through the chapter it sits, and a filled circular arrow on the trailing
/// edge — the one solid accent shape on Home, because this is the one card whose whole purpose is
/// to be tapped. Everything else on the screen reports; this resumes.
struct ContinueReadingCard: View {
    let position: ReadingPosition
    let surah: Surah?
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                RuledPageMark()

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(l10n.string(.quranContinueReading))
                        .appFont(.caption, weight: .semibold)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.textSecondary)

                    Text(place)
                        .appFont(.callout, weight: .semibold)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let fraction {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear)
                            .tint(theme.accent)
                            .padding(.top, AppSpacing.xs)
                            // The line above already names the verse; a bar saying it a second
                            // time in percent is noise to anyone listening rather than looking.
                            .accessibilityHidden(true)
                    }
                }

                Spacer(minLength: AppSpacing.sm)

                Image(systemName: "chevron.forward")
                    .appFont(.footnote, weight: .bold)
                    .foregroundStyle(theme.background)
                    .frame(width: 34, height: 34)
                    .background(theme.accent, in: .circle)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
                .appHover()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The chapter's Arabic name and the verse — the one line that says where "continue" goes.
    ///
    /// The name stays Arabic in either interface language, as it does everywhere else a chapter
    /// is named; the number follows the reader's digits.
    private var place: String {
        let name = surah?.arabicName ?? ""
        let verse = l10n.string(position.reference.verse, grouped: false)
        return "\(name) \(l10n.string(.quranVerseLabel)) \(verse)"
    }

    /// How far through the chapter the position sits, or `nil` when the chapter is not to hand.
    ///
    /// Absent rather than zero: a bar sitting empty would say the reader is at the start of a
    /// chapter they may be at the end of, which is worse than the bar not being there.
    private var fraction: Double? {
        guard let surah, surah.verseCount > 0 else { return nil }
        return min(Double(position.reference.verse) / Double(surah.verseCount), 1)
    }
}

/// A ruled page, small enough to be a mark rather than a picture.
///
/// The "paper and ink" half of the design's motif, at the size of an icon: what makes this card
/// legible at a glance is the shape of a page, and an SF Symbol book beside four other symbols
/// on the same screen is not that.
private struct RuledPageMark: View {
    @Environment(\.theme) private var theme

    @ScaledMetric private var width: CGFloat = 42
    @ScaledMetric private var height: CGFloat = 52

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { _ in
                Rectangle()
                    .fill(theme.textSecondary.opacity(0.22))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(width: width, height: height)
        .background(theme.accent.opacity(0.10), in: .rect(cornerRadius: AppRadius.sm))
        .accessibilityHidden(true)
    }
}
