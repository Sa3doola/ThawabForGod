//
//  MenuBarController.swift
//  ThawabForGod
//

#if os(macOS)
import AppKit
import SwiftUI

/// The status item, the popover, and the heartbeat that keeps the countdown moving.
///
/// AppKit rather than SwiftUI's `MenuBarExtra`, and the reason is the *label*. A `MenuBarExtra`
/// label is rendered once and is unreliable about redrawing on a schedule; the countdown in the
/// menu bar is the whole point of this slice, and it has to tick. `NSStatusItem` gives direct
/// control over when the title is rewritten, and the panel is an `NSPopover` hosting the same
/// SwiftUI the rest of the app is made of.
///
/// **Owned by `AppContainer`, not by the app delegate.** AppKit constructs the delegate itself
/// with no argument list to inject anything through, and this needs six collaborators. The
/// container already owns every other long-lived object, so it owns this one too; `MacAppDelegate`
/// keeps only what genuinely belongs to the application object.
///
/// It holds no logic. Which prayer, how long, how often to redraw — all of it is
/// `MenuBarPanelViewModel`, which is where the tests are.
@MainActor
final class MenuBarController {

    private let viewModel: MenuBarPanelViewModel
    private let preferences: MenuBarPreferences
    private let themeManager: ThemeManager
    private let l10n: LocalizationManager
    private let open: (DeepLink) -> Void

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var ticker: Task<Void, Never>?

    init(
        viewModel: MenuBarPanelViewModel,
        preferences: MenuBarPreferences,
        themeManager: ThemeManager,
        l10n: LocalizationManager,
        open: @escaping (DeepLink) -> Void
    ) {
        self.viewModel = viewModel
        self.preferences = preferences
        self.themeManager = themeManager
        self.l10n = l10n
        self.open = open
    }

    // MARK: Lifecycle

    /// Brings the status item and the activation policy in line with the preferences.
    ///
    /// Idempotent, and called both at launch and on every change, so there is one path rather
    /// than an install path and a separate update path that could disagree.
    func apply() {
        if preferences.isMenuBarEnabled {
            install()
            // `install()` returns early when the item is already there, so the redraw is here
            // rather than inside it: changing the *style* changes nothing about whether the item
            // exists, and without this the new rung would not appear until the next beat — up to
            // a minute of a switch that looked like it had not worked.
            redraw()
        } else {
            remove()
        }

        // At runtime rather than through `LSUIElement` in the plist: a plist flag cannot be
        // turned back off without relaunching the app, and this is a switch in Settings.
        NSApp.setActivationPolicy(preferences.isMenuBarOnly ? .accessory : .regular)
    }

    private func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item

        redraw()
        startTicking()
    }

    private func remove() {
        ticker?.cancel()
        ticker = nil
        popover?.performClose(nil)
        popover = nil

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    /// Recomputes from scratch — for a settings change, or a wake from sleep where the ticker
    /// has been asleep along with the machine.
    func refresh() {
        guard statusItem != nil else { return }

        viewModel.refresh()
        redraw()
    }

    // MARK: The heartbeat

    /// A `Task` that sleeps for whatever the view model says the next beat is worth.
    ///
    /// A self-rescheduling sleep rather than a fixed-interval stream, because the interval is not
    /// fixed: a second inside the last hour, half a minute outside it. Structured, so cancelling
    /// it in `remove()` is the whole teardown — there is no timer to invalidate and nothing to
    /// leak.
    private func startTicking() {
        ticker?.cancel()

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = self?.viewModel.tickInterval else { return }

                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return // cancelled mid-sleep
                }

                guard let self else { return }

                viewModel.tick(Date())
                redraw()
            }
        }
    }

    // MARK: Drawing

    private func redraw() {
        guard let button = statusItem?.button else { return }

        let rung = preferences.statusStyle.rung(freeWidth: freeMenuBarWidth)
        let title = viewModel.statusTitle(rung: rung)

        button.image = title.symbol.flatMap {
            let image = NSImage(
                systemSymbolName: $0,
                accessibilityDescription: l10n.string(.appName)
            )
            // A template image, so AppKit inverts it for a dark menu bar rather than the app
            // owning two artworks and a guess about which bar it is in.
            image?.isTemplate = true
            return image
        }

        button.imagePosition = title.text.isEmpty ? .imageOnly : .imageLeading
        button.attributedTitle = attributed(title.text, hasSymbol: title.symbol != nil)
        button.toolTip = title.tooltip
    }

    /// The title, in a font whose digits are all the same width.
    ///
    /// **This is the other half of holding still**, and without it the slot does nothing: padding
    /// a countdown to a fixed number of characters only fixes its width if the characters are of
    /// a fixed width, and the menu bar's font is proportional — `1` is markedly narrower than
    /// `8` in it. `monospacedDigitSystemFont` keeps the menu bar's own metrics and size while
    /// making every digit, and the FIGURE SPACE that pads them, share one advance.
    ///
    /// The leading space is drawn as part of the string rather than by `imagePosition`, so it is
    /// absent at the rung that has no symbol instead of leaving the text hanging off its edge.
    private func attributed(_ text: String, hasSymbol: Bool) -> NSAttributedString {
        guard !text.isEmpty else { return NSAttributedString(string: "") }

        return NSAttributedString(
            string: hasSymbol ? " \(text)" : text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: NSFont.systemFontSize(for: .small),
                    weight: .regular
                )
            ]
        )
    }

    /// Roughly how much of the menu bar is not already spoken for, in points.
    ///
    /// Measured as the room between the app menus on the left and this item on the right, which
    /// is the space every *other* status item is competing for. `nil` before the item has a
    /// window to measure — see `MenuBarStatusStyle.rung(freeWidth:)`, which treats an unmeasured
    /// bar as a roomy one rather than flickering through the ladder at launch.
    ///
    /// **An estimate, and deliberately a cheap one.** AppKit publishes no "free menu bar width",
    /// and the exact figure would need the widths of the frontmost app's menus, which change
    /// with every app switch. What the ladder needs is not a measurement but an order of
    /// magnitude — is the bar comfortable, tight, or hopeless — and the item's own left edge
    /// answers that, because macOS lays status items out from the right and pushes ours further
    /// left with every one that appears. Anyone who wants a guarantee rather than an estimate
    /// pins a rung in Settings, which is what `MenuBarStatusStyle`'s other three cases are for.
    private var freeMenuBarWidth: CGFloat? {
        guard let window = statusItem?.button?.window else { return nil }

        let menus = NSApp.mainMenu?.size.width ?? 0

        return max(0, window.frame.minX - menus)
    }

    // MARK: The panel

    @objc
    private func togglePanel() {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        showPanel()
    }

    private func showPanel() {
        guard let button = statusItem?.button else { return }

        // Rebuilt on each open rather than kept alive: the panel is a snapshot of a moment, and a
        // hosting controller held across hours of the app being idle would be a retained view
        // tree observing a view model nobody is looking at.
        viewModel.refresh()
        redraw()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPanelView(
                viewModel: viewModel,
                open: { [weak self] link in self?.openInApp(link) },
                dismissPanel: { [weak self] in self?.dismissPanel() },
                quit: { NSApp.terminate(nil) }
            )
            .themed(themeManager)
            .localized(l10n)
        )

        self.popover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: Leaving the panel

    /// Routes a link and puts a window in front of the user.
    ///
    /// Both halves are needed and neither is enough alone. `open(_:)` moves the router, which is
    /// what decides *which* section — but on a Mac the window may be closed, or behind another
    /// app, and a router change nobody can see is not an answer. Falling back to the app's own
    /// URL scheme is what covers the closed-window case: `WindowGroup` opens one to handle it,
    /// which is the same door a widget tap comes through.
    private func openInApp(_ link: DeepLink) {
        popover?.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)

        let window = NSApp.windows.first { $0.canBecomeMain && $0.isRestorable }

        if let window {
            open(link)
            window.makeKeyAndOrderFront(nil)
        } else {
            NSWorkspace.shared.open(link.url)
        }
    }

    /// Gets the panel out of the way of a window that is about to open, and brings the app
    /// forward behind it.
    ///
    /// **This is all that is left of what used to be `openSettings()`.** That method sent
    /// `showSettingsWindow:` — and, failing that, Ventura's `showPreferencesWindow:` — down the
    /// responder chain, which is the trick every Mac app used to reach a SwiftUI `Settings`
    /// scene. Neither selector exists any more: `sendAction` returns `false` for both, the loop
    /// falls through, and the row does nothing at all. The Settings scene is opened by
    /// `SettingsLink` in `MenuBarPanelView` now, because it is a *view* rather than an action and
    /// there is no version of it AppKit can call.
    ///
    /// What stays here is the half that is genuinely AppKit's. The activation is not optional
    /// window-fussing: with the Dock icon hidden — which `MenuBarPreferences` lets a reader
    /// choose — the app is an accessory, and a window it opens does not come to the front on its
    /// own. It is deferred one hop so the link's own action runs first and the Settings window is
    /// the frontmost thing there is to raise; activating before it exists would raise the main
    /// window instead, which is the wrong window and the harder bug to see.
    private func dismissPanel() {
        popover?.performClose(nil)

        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
#endif
