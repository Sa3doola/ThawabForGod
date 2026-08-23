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

        button.image = NSImage(
            systemSymbolName: viewModel.statusSymbol,
            accessibilityDescription: l10n.string(.appName)
        )
        button.image?.isTemplate = true
        button.imagePosition = viewModel.statusTitle == nil ? .imageOnly : .imageLeading
        button.title = viewModel.statusTitle.map { " \($0)" } ?? ""
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
                openSettings: { [weak self] in self?.openSettings() },
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

    /// The `Settings` scene, which has no public API to open.
    ///
    /// Two selectors because Apple renamed the action: `showSettingsWindow:` from Ventura,
    /// `showPreferencesWindow:` before it. Sent to `nil` so the responder chain finds whoever
    /// implements it, and neither is a hard dependency — if a future release renames it again the
    /// button does nothing rather than crashing, and ⌘, still works.
    private func openSettings() {
        popover?.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)

        let selectors = [
            Selector(("showSettingsWindow:")),
            Selector(("showPreferencesWindow:"))
        ]

        for selector in selectors where NSApp.sendAction(selector, to: nil, from: nil) {
            return
        }
    }
}
#endif
