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
    let openSettings: () -> Void
    let quit: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let noticeKey = viewModel.noticeKey {
                notice(noticeKey)
            } else {
                Divider()
                schedule
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 260)
        .background(theme.background)
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        if let upcoming = viewModel.upcoming, let remaining = viewModel.remaining {
            VStack(alignment: .leading, spacing: 2) {
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
        VStack(spacing: 3) {
            ForEach(viewModel.times) { time in
                let isCurrent = time.prayer == viewModel.currentPrayer

                HStack(spacing: 8) {
                    Image(systemName: time.prayer.symbol)
                        .appFont(.caption)
                        .frame(width: 16)

                    Text(l10n.string(time.prayer.labelKey))
                        .appFont(.callout, weight: isCurrent ? .semibold : .regular)

                    Spacer(minLength: 8)

                    Text(l10n.timeString(time.date))
                        .appFont(.callout, weight: isCurrent ? .semibold : .regular)
                        .monospacedDigit()
                }
                .foregroundStyle(isCurrent ? theme.accent : theme.textPrimary)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            footerButton(.homeTabLabel, symbol: "house") { open(.home) }
            footerButton(.qiblaTitle, symbol: "location.north.line") { open(.qibla) }
            footerButton(.quranTitle, symbol: "book.closed") { open(.quran) }

            Spacer(minLength: 0)

            footerButton(.settingsTitle, symbol: "gearshape", action: openSettings)
            footerButton(.menuBarQuit, symbol: "power", action: quit)
        }
    }

    /// A symbol with its name as the accessibility label and the tooltip — a row of five labelled
    /// buttons would not fit the panel's width in either language, and a row of five bare glyphs
    /// would be unreadable to VoiceOver.
    private func footerButton(
        _ titleKey: L10nKey,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 26, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(l10n.string(titleKey))
        .accessibilityLabel(l10n.string(titleKey))
    }
}
#endif
