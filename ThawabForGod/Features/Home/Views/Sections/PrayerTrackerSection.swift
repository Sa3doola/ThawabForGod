//
//  PrayerTrackerSection.swift
//  ThawabForGod
//

import SwiftUI

/// Today's five, and the run of days behind them.
///
/// Five tiles rather than a bare `3 / 5`, because the number on its own is a report and the
/// tiles are the thing you actually use — marking a prayer is a one-tap job that should not
/// need a sheet opened first. The sheet is still where a *past* day is marked; this is today.
struct PrayerTrackerSection: View {
    let record: PrayerRecord
    let streak: Int
    let setCompleted: @MainActor @Sendable (Prayer, Bool) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header

            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(PrayerRecord.trackable.enumerated()), id: \.element) { index, prayer in
                    TrackerTile(
                        prayer: prayer,
                        isCompleted: record.isCompleted(prayer),
                        ordinal: index + 1,
                        setCompleted: { setCompleted(prayer, $0) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var header: some View {
        HStack {
            Text(l10n.string(.homeSectionPrayerTracker))
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: AppSpacing.sm)

            if streak > 0 {
                Label(
                    l10n.string(.prayerStreakLabel, l10n.string(streak, grouped: false)),
                    systemImage: "flame"
                )
                .appFont(.caption, weight: .medium)
                .foregroundStyle(theme.accent)
            }

            Text(
                l10n.string(
                    .activityProgress,
                    l10n.string(record.completedCount, grouped: false),
                    l10n.string(PrayerRecord.trackable.count, grouped: false)
                )
            )
            .appFont(.subheadline, weight: .semibold)
            .foregroundStyle(theme.textSecondary)
            .monospacedDigit()
        }
    }
}

/// One prayer's mark: a filled tile when it is done, a dashed outline when it is not.
///
/// **The fill is `Success`, never the accent.** The accent is user-chosen and may be any of four
/// colours, so it cannot be the thing that says "prayed" — a rose tracker beside a rose active
/// tab would be two different meanings in one colour. `Success`, `Warning` and `Danger` are
/// fixed across all four accents precisely so state can live in them.
///
/// And the state is in the *shape* as well: done is a solid tile with a mark in it, not-done is a
/// dashed edge around nothing. That is what keeps the row readable to someone who cannot separate
/// the two colours at all.
private struct TrackerTile: View {
    let prayer: Prayer
    let isCompleted: Bool

    /// Where this prayer sits in the day, one-based — the number its keyboard shortcut carries
    /// on the Mac. Passed in rather than derived, because `Prayer.allCases` includes sunrise and
    /// the tracker's five do not.
    let ordinal: Int

    let setCompleted: @MainActor @Sendable (Bool) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    @ScaledMetric private var height: CGFloat = 46

    var body: some View {
        Button {
            setCompleted(!isCompleted)
        } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(isCompleted ? theme.success : theme.separator.opacity(0.35))

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .appFont(.subheadline, weight: .bold)
                            // The ground rather than `Surface`: the tile is a solid block of
                            // Success, and the page's own background is what reads as cut out
                            // of it in both appearances.
                            .foregroundStyle(theme.background)
                    } else {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .strokeBorder(
                                theme.separator,
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)

                Text(l10n.string(prayer.labelKey))
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        // Logging a prayer from the keyboard, which on a Mac is where the hands already are.
        //
        // **Control-command, not plain command**, though the design annotates these as ⌘1–⌘5:
        // ⌘1–⌘4 already switch sections through `SectionCommands`, and a shortcut that moved the
        // window *and* marked a prayer would be a bug in whichever of the two the user did not
        // mean. The design was drawn without that constraint in view; the sections had it first,
        // and they are reachable from every screen while this tile is only on Home.
        #if os(macOS)
        .keyboardShortcut(
            KeyEquivalent(Character("\(ordinal)")),
            modifiers: [.control, .command]
        )
        #endif
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(prayer.labelKey))
        // Read as "selected" rather than as a button with a state buried in its label, which is
        // what a checkbox-shaped control is expected to say.
        .accessibilityAddTraits(isCompleted ? [.isButton, .isSelected] : .isButton)
    }
}
