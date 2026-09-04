//
//  MenuBarPanelView.swift
//  ThawabForGod
//

#if os(macOS)
import SwiftUI

/// What the status item opens: the prayer being counted down to, the whole day beneath it, and a
/// row of ways out.
///
/// A popover rather than a menu, which is the decision the whole slice turns on. `NSMenu` can
/// only draw rows of text, and the thing worth having in a Mac menu bar is the *countdown* —
/// large, live, and readable from across a desk. That needs SwiftUI, which needs an `NSPopover`
/// hosting it.
struct MenuBarPanelView: View {

    let viewModel: MenuBarPanelViewModel

    /// Everything that leaves the panel. Supplied by `MenuBarController`, because activating the
    /// app and ordering a window forward is AppKit's business and not a view's.
    let open: (DeepLink) -> Void

    /// Closes the popover and brings the app forward. **Not** an "open settings" closure: the
    /// Settings scene is opened by `SettingsLink` in the row itself, because SwiftUI owns that
    /// scene and gives AppKit no supported way in — see `settingsRow`.
    let dismissPanel: () -> Void

    let quit: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { band }
                // On the ramp the palette inverts, so the header goes on reading the same tokens
                // the rest of the panel does — see `Theme.onDayRamp`.
                .environment(\.theme, rampStop == nil ? theme : theme.onDayRamp)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let noticeKey = viewModel.noticeKey {
                    notice(noticeKey)
                } else {
                    schedule
                }

                Divider()
                footer
            }
            .padding(AppSpacing.lg)
        }
        .frame(width: 260)
        .background(theme.background)
        // Every time the panel opens, because what has been marked can have changed anywhere —
        // Home, the day sheet, another device. The status item itself never shows it, so there is
        // nothing to keep in step while the panel is closed.
        .task { await viewModel.loadRecord() }
    }

    // MARK: Header

    /// The third and last place the day ramp is allowed to appear — the app's card, the widget,
    /// and this. It bleeds to the popover's own edges, so the panel opens as a piece of the sky
    /// with the day listed under it rather than as a menu with a coloured rectangle inside it.
    ///
    /// It steps per prayer rather than blending, for the widget's reason turned around: this
    /// panel *is* redrawn every second in the last hour, and running the blend on that ticker
    /// would repaint a gradient and a lattice sixty times a minute to move a colour nobody can
    /// see move. The prayer is what changes the light here.
    @ViewBuilder
    private var band: some View {
        if let rampStop {
            DayRampBackground(stop: rampStop)
        } else {
            theme.background
        }
    }

    /// `nil` when there is nothing to count down to — no position, or a latitude where the times
    /// cannot be computed. The ramp is a claim about the time of day, and a panel that could not
    /// work out the day has no business making one.
    private var rampStop: DayRampStop? {
        guard let upcoming = viewModel.upcoming, viewModel.noticeKey == nil else { return nil }
        return DayRamp.stop(for: viewModel.currentPrayer ?? upcoming.prayer)
    }

    @ViewBuilder
    private var header: some View {
        if let upcoming = viewModel.upcoming, let remaining = viewModel.remaining {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Label {
                    Text(l10n.string(upcoming.prayer.labelKey))
                        .appFont(.subheadline, weight: .semibold)
                } icon: {
                    Image(systemName: upcoming.prayer.symbol)
                }
                .foregroundStyle(theme.accent)

                // Not `Text(_:style: .timer)`: this view is redrawn on a ticker the view model
                // paces, and the app's own formatter is what keeps the digits and the bidi
                // isolates right. See `MenuBarPanelViewModel.statusTitle`.
                Text(l10n.countdownString(remaining))
                    .appFont(.largeTitle, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)

                Text(l10n.timeString(upcoming.date))
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        } else {
            Text(l10n.string(.appName))
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func notice(_ key: L10nKey) -> some View {
        Text(l10n.string(key))
            .appFont(.footnote)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: The day

    private var schedule: some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(viewModel.times) { time in
                let isCurrent = time.prayer == viewModel.currentPrayer

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: time.prayer.symbol)
                        .appFont(.caption)
                        .frame(width: 16)

                    Text(l10n.string(time.prayer.labelKey))
                        .appFont(.callout, weight: isCurrent ? .semibold : .regular)

                    Spacer(minLength: AppSpacing.sm)

                    Text(l10n.timeString(time.date))
                        .appFont(.callout, weight: isCurrent ? .semibold : .regular)
                        .monospacedDigit()
                }
                .foregroundStyle(isCurrent ? theme.accent : theme.textPrimary)
            }
        }
    }

    // MARK: Footer

    /// The ways out of the panel, and the one thing that can be done inside it.
    ///
    /// **Named rows rather than the row of bare glyphs this replaces.** Five unlabelled symbols
    /// in a 260-point panel are a puzzle — "power" and "gear" are guessable, a compass needle is
    /// not — and the tooltip that explained them only appears after the pointer has already
    /// rested on the wrong one. Rows also give the shortcuts somewhere to be shown, which is the
    /// thing that turns them from a secret into a feature: a Mac user who sees `⌘K` beside Qibla
    /// once stops opening the panel to get there.
    ///
    /// Logging leads, because it is the only row that does something rather than going somewhere.
    private var footer: some View {
        VStack(spacing: 0) {
            if let prayer = viewModel.loggablePrayer {
                actionRow(
                    label: l10n.string(
                        viewModel.hasLoggedCurrentPrayer ? .menuBarLoggedPrayer : .menuBarLogPrayer,
                        l10n.string(prayer.labelKey)
                    ),
                    symbol: viewModel.hasLoggedCurrentPrayer ? "checkmark.circle.fill" : "checkmark.circle",
                    tint: viewModel.hasLoggedCurrentPrayer ? theme.success : theme.textSecondary,
                    shortcut: "L",
                    modifiers: .command
                ) {
                    Task { await viewModel.toggleLoggingCurrentPrayer() }
                }
            }

            actionRow(label: l10n.string(.appName), symbol: "house", shortcut: "O", modifiers: .command) {
                open(.home)
            }

            actionRow(label: l10n.string(.qiblaTitle), symbol: "location.north.line", shortcut: "K", modifiers: .command) {
                open(.qibla)
            }

            actionRow(label: l10n.string(.quranTitle), symbol: "book.closed", shortcut: "B", modifiers: .command) {
                open(.quran)
            }

            settingsRow

            actionRow(label: l10n.string(.menuBarQuit), symbol: "power", shortcut: "Q", modifiers: .command, action: quit)
        }
        // Negative on the panel's own padding, so a hovered row's wash reaches the popover's
        // edges the way a menu highlight does rather than stopping short of them.
        .padding(.horizontal, -AppSpacing.sm)
    }

    /// One row: a symbol, a name, and the keys that do the same thing.
    ///
    /// The shortcut is both *shown* and *bound*. `keyboardShortcut` on a button inside a popover
    /// only fires while the popover has key focus, which is exactly when the reader can see the
    /// hint — so the two are true together or absent together, and the panel never advertises a
    /// key combination that does nothing.
    private func actionRow(
        label: String,
        symbol: String,
        tint: Color? = nil,
        shortcut: KeyEquivalent,
        modifiers: EventModifiers,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            rowLabel(label: label, symbol: symbol, tint: tint, shortcut: shortcut, modifiers: modifiers)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: modifiers)
        .appHover(radius: AppRadius.sm)
        .accessibilityLabel(label)
    }

    /// The Settings row, and **the one row that is not a `Button`.**
    ///
    /// The Settings scene belongs to SwiftUI and has no AppKit door. This row used to send
    /// `showSettingsWindow:` down the responder chain — the trick every Mac app used before
    /// Sonoma — and it now does nothing at all: the selector is gone, `sendAction` returns
    /// `false`, and the loop that tried both spellings fell through in silence. Xcode says so as
    /// a warning on the call, which is the only reason a button that quietly stopped working
    /// would ever be noticed.
    ///
    /// `SettingsLink` is the replacement, and it is a *view* rather than an action — so this has
    /// to be built here in SwiftUI rather than handed to `MenuBarController` as a closure. What
    /// the controller still owns is the part that is genuinely AppKit's: closing the popover and
    /// bringing the app forward, which is `dismissPanel`.
    ///
    /// The dismissal rides a `simultaneousGesture` rather than replacing the link's own action,
    /// because `SettingsLink` does not expose one. It fires alongside, not instead.
    private var settingsRow: some View {
        SettingsLink {
            rowLabel(
                label: l10n.string(.settingsTitle),
                symbol: "gearshape",
                tint: nil,
                shortcut: ",",
                modifiers: .command
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(",", modifiers: .command)
        .appHover(radius: AppRadius.sm)
        .accessibilityLabel(l10n.string(.settingsTitle))
        .simultaneousGesture(TapGesture().onEnded { dismissPanel() })
    }

    /// The inside of a row, shared by the buttons and by `SettingsLink` — which needs the same
    /// thing drawn in a view it builds itself.
    private func rowLabel(
        label: String,
        symbol: String,
        tint: Color?,
        shortcut: KeyEquivalent,
        modifiers: EventModifiers
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: symbol)
                .appFont(.footnote)
                .foregroundStyle(tint ?? theme.textSecondary)
                .frame(width: 16)

            Text(label)
                .appFont(.callout)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.sm)

            Text(hint(shortcut, modifiers))
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .contentShape(.rect(cornerRadius: AppRadius.sm))
    }

    /// `⌘K` — built from the same two values the binding uses, so the hint cannot drift from what
    /// the keys actually do.
    private func hint(_ shortcut: KeyEquivalent, _ modifiers: EventModifiers) -> String {
        // Left to right whatever the interface language: these are the glyphs printed on the
        // keyboard, and a reader in Arabic presses the same keys in the same order.
        let symbols = modifiers.contains(.command) ? "\u{2318}" : ""
        return "\u{2066}" + symbols + String(shortcut.character).uppercased() + "\u{2069}"
    }

}
#endif
