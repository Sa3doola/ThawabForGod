//
//  RecentActivitySection.swift
//  ThawabForGod
//

import SwiftUI

/// Where the user was, in each of the three things they can be in the middle of.
///
/// A horizontal row rather than a vertical list, because there are at most three of them and they
/// are peers — a stack would give the first one a prominence the ordering does not mean. The
/// section is drawn only when there is something in it; the caller decides that, because a
/// heading with nothing under it is worse than no heading at all.
struct RecentActivitySection: View {
    let items: [HomeViewModel.RecentActivityItem]
    let open: (AppRoute) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(l10n.string(.homeSectionLastActivity))
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                // `.top` so the labels line up; the chips themselves stretch to match — see the
                // chip's own frame.
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    ForEach(items) { item in
                        RecentActivityChip(item: item, open: open)
                    }
                }
                // The chips carry their own background, so the row needs room to breathe at the
                // edges without the scroll view clipping the corner of the first one.
                .padding(.vertical, 2)
            }
        }
    }
}

/// One chip: what it was, where it got to, and a bar for how far.
private struct RecentActivityChip: View {
    let item: HomeViewModel.RecentActivityItem
    let open: (AppRoute) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    @ScaledMetric private var width: CGFloat = 168

    var body: some View {
        Button {
            guard let route = item.activity.route else { return }
            open(route)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label {
                    Text(l10n.string(item.activity.kind.titleKey))
                        .appFont(.caption, weight: .semibold)
                } icon: {
                    Image(systemName: item.activity.kind.symbol)
                        .appFont(.caption)
                }
                .foregroundStyle(theme.textSecondary)

                Text(place)
                    .appFont(.subheadline, weight: .medium)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let fraction = item.activity.fraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .tint(theme.accent)
                }
            }
            .frame(width: width, alignment: .leading)
            .padding(AppSpacing.md)
            // Equal heights across the row. Chips carry different amounts of text — a chapter's
            // name wraps where a dhikr's does not — and `maxHeight` inside an `HStack` grows each
            // one to the tallest, which is what keeps the row a row rather than a skyline.
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .appCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// The one line that says where this got to.
    ///
    /// Assembled from parts rather than stored as a sentence: the name comes from the corpus, the
    /// numbers go through the digit formatter, and both are resolved now rather than when the
    /// activity was recorded.
    private var place: String {
        switch item.activity.kind {
        case .quran:
            let verse = "\(l10n.string(.quranVerseLabel)) \(l10n.string(item.activity.progressValue, grouped: false))"
            guard let subject = item.subject else { return verse }
            return "\(subject) — \(verse)"

        case .adhkar:
            guard let category = item.activity.adhkarCategory else { return counted }
            return "\(l10n.string(category.titleKey)) — \(counted)"

        case .tasbih:
            guard let subject = item.subject else { return counted }
            return "\(subject) — \(counted)"
        }
    }

    /// `7 / 28`, in the user's digits and isolated from the paragraph's direction — a count
    /// against a target reads the same way round in both languages.
    private var counted: String {
        let value = l10n.string(item.activity.progressValue, grouped: false)
        let total = l10n.string(item.activity.progressTotal, grouped: false)
        return l10n.string(.activityProgress, value, total)
    }
}
