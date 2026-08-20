//
//  ShortcutsSection.swift
//  ThawabForGod
//

import SwiftUI

/// The one-tap circles: the handful of screens this user reaches for, in the order they chose.
///
/// A grid rather than a scrolling row, because a shortcut that has to be scrolled to is not a
/// shortcut. The cap on how many can be shown lives in `HomeLayout` for the same reason — eight
/// is two full rows on a phone, and a wall of circles is not a fast path to anything.
///
/// **This is not a second door to the screens in Home's toolbar.** The Qibla, the tasbih and the
/// 99 names stay reachable there whatever the user does here, because this section can be hidden
/// entirely and a feature must not become unreachable by preference. The toolbar is the way in;
/// this is the way in *quickly*.
struct ShortcutsSection: View {
    let shortcuts: [HomeShortcut]
    let open: (AppRoute) -> Void

    /// Opens the customization screen. In the section's own header rather than only in Settings,
    /// because the moment a user wants to change these is the moment they are looking at them.
    let edit: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// The narrowest a circle and its label may be. `@ScaledMetric` so the grid *reflows* at
    /// larger type sizes — four across on a phone, fewer as the labels grow, more on an iPad —
    /// rather than keeping four columns and squeezing the words.
    @ScaledMetric private var itemWidth: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: itemWidth), spacing: 8)],
                spacing: 16
            ) {
                ForEach(shortcuts, id: \.self) { shortcut in
                    ShortcutButton(shortcut: shortcut) {
                        guard let route = shortcut.route else { return }
                        open(route)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(l10n.string(.homeSectionShortcuts))
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            Button(action: edit) {
                Text(l10n.string(.homeCustomizeAction))
                    .appFont(.subheadline, weight: .medium)
                    .foregroundStyle(theme.accent)
            }
        }
    }
}

/// One circle and its label.
private struct ShortcutButton: View {
    let shortcut: HomeShortcut
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    @ScaledMetric private var circle: CGFloat = 56

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: shortcut.symbol)
                    .appFont(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: circle, height: circle)
                    .background(theme.accent.opacity(0.12), in: .circle)

                Text(l10n.string(shortcut.labelKey))
                    .appFont(.caption)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    // Two lines, then shrink. "أذكار الصباح" and "Morning adhkar" both want
                    // two; a third would push the row below it out of alignment.
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
