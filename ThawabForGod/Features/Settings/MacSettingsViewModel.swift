//
//  MacSettingsViewModel.swift
//  ThawabForGod
//

import Observation

/// The three choices that only exist on a Mac: the menu bar, the Dock icon, and starting at login.
///
/// **No `#if os(macOS)`, though `MacSettingsView` has one**: nothing here imports AppKit, and the
/// suite runs on the iOS simulator, so gating it would compile it out of the only place it is
/// tested. See `MenuBarPanelViewModel` for the same note.
///
/// Like every other screen in Settings it stores nothing — `MenuBarPreferences` owns the first
/// two and persists them, and the third is not a preference of this app's at all but a fact held
/// by macOS, read fresh each time it is asked for.
@Observable
@MainActor
final class MacSettingsViewModel {

    /// What macOS says about the login item, re-read on every appearance.
    private(set) var launchAtLogin: LaunchAtLoginStatus = .disabled

    /// Set when `enable()` or `disable()` threw. Shown, rather than swallowed, because the
    /// commonest cause is one the user can act on: the app is not in `/Applications`.
    private(set) var launchAtLoginFailed = false

    @ObservationIgnored private let preferences: MenuBarPreferences
    @ObservationIgnored private let loginItem: any LaunchAtLoginServicing

    /// Applied whenever a menu-bar preference changes. The controller is AppKit and lives at the
    /// composition root; this screen only says that something changed.
    @ObservationIgnored private let onMenuBarChanged: () -> Void

    init(
        preferences: MenuBarPreferences,
        loginItem: any LaunchAtLoginServicing,
        onMenuBarChanged: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.loginItem = loginItem
        self.onMenuBarChanged = onMenuBarChanged
    }

    // MARK: The menu bar

    var isMenuBarEnabled: Bool { preferences.isMenuBarEnabled }
    var isMenuBarOnly: Bool { preferences.isMenuBarOnly }

    /// Whether hiding the Dock icon is even offerable. With no status item there would be no way
    /// back to the app at all, so the switch is disabled rather than allowed to strand anyone.
    var canHideDockIcon: Bool { preferences.isMenuBarEnabled }

    func setMenuBarEnabled(_ isEnabled: Bool) {
        preferences.setMenuBarEnabled(isEnabled)
        onMenuBarChanged()
    }

    func setMenuBarOnly(_ isOnly: Bool) {
        preferences.setMenuBarOnly(isOnly)
        onMenuBarChanged()
    }

    /// How much of the status item to draw.
    var statusStyle: MenuBarStatusStyle { preferences.statusStyle }

    /// Whether the choice is even offerable — with no status item there is nothing to style.
    var canChooseStatusStyle: Bool { preferences.isMenuBarEnabled }

    func setStatusStyle(_ style: MenuBarStatusStyle) {
        preferences.setStatusStyle(style)
        onMenuBarChanged()
    }

    // MARK: Launch at login

    /// Whether the switch reads as on. `requiresApproval` does — the user asked for it, and the
    /// row's job is then to explain why it has not taken effect.
    var isLaunchAtLoginOn: Bool { launchAtLogin.isOn }

    /// Whether to show the row that opens System Settings. Only `requiresApproval` can be
    /// resolved there, so it is the only state that offers it.
    var needsApproval: Bool { launchAtLogin == .requiresApproval }

    /// `SMAppService` cannot answer for an app outside `/Applications`, which is every debug
    /// build. Saying so beats a switch that silently refuses to move.
    var isLaunchAtLoginUnavailable: Bool { launchAtLogin == .unavailable }

    /// Re-read on each appearance: the user can revoke this in System Settings while the app is
    /// running, and a value cached at construction would be a lie by the time anyone looked.
    func loadLaunchAtLogin() {
        launchAtLogin = loginItem.status
    }

    func setLaunchAtLogin(_ isOn: Bool) {
        launchAtLoginFailed = false

        do {
            if isOn {
                try loginItem.enable()
            } else {
                try loginItem.disable()
            }
        } catch {
            launchAtLoginFailed = true
        }

        // Always re-read rather than assuming the write took: registering can succeed into
        // `requiresApproval`, which is neither the value asked for nor a failure.
        loadLaunchAtLogin()
    }

    func openLoginItemsSettings() {
        loginItem.openSystemSettings()
    }
}
