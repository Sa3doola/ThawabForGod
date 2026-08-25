//
//  MenuBarPreferences.swift
//  ThawabForGod
//

import Observation

/// How Noor sits on the Mac: in the menu bar, in the Dock, or only the former.
///
/// In `Core/MacIntegration` beside the login item rather than in `Features/MenuBar`, for the
/// reason `ReminderPreferences` sits in `Core/Notifications` rather than in Settings: a
/// preference is cross-cutting infrastructure that several layers read, and the feature folder
/// holds the screen that edits it. The subsystem is named for the *subject* — how this app
/// integrates with macOS — because both halves of it answer that and neither is only about a
/// menu bar or only about logging in.
///
/// The sibling of `ReminderPreferences` and `ThemeManager`, and here for the same reason: two
/// places act on the choice at once — Settings edits it and `MenuBarController` obeys it — so it
/// has to be observable rather than read once at launch.
///
/// **The two defaults point opposite ways, deliberately.** The status item is on unless the user
/// turns it off, because a glanceable countdown is most of what a Mac build of this app is for.
/// Dock-icon hiding is off unless they ask, because an app that vanished from the Dock on its own
/// would look like it had quit. Neither default is written to the store — unset means "never
/// opinionated", which is the rule `SettingsStore` states.
@Observable
@MainActor
final class MenuBarPreferences {

    private(set) var isMenuBarEnabled: Bool
    private(set) var isMenuBarOnly: Bool

    /// How much of the status item to draw. `automatic` unless the user has said otherwise —
    /// which is the third default here, and it points the same way as the first: the item shows
    /// everything it can, and gives ground only when the bar makes it.
    private(set) var statusStyle: MenuBarStatusStyle

    @ObservationIgnored private let settingsStore: any SettingsStore

    init(settingsStore: any SettingsStore) {
        self.settingsStore = settingsStore
        self.isMenuBarEnabled = settingsStore.bool(for: .menuBarEnabled) ?? true
        self.isMenuBarOnly = settingsStore.bool(for: .menuBarOnly) ?? false
        // An unreadable stored value falls back to the default rather than trapping: this is a
        // raw string in a preferences file, and a build that renamed a case must not crash the
        // one after it.
        self.statusStyle = settingsStore.string(for: .menuBarStatusStyle)
            .flatMap(MenuBarStatusStyle.init(rawValue:)) ?? .automatic
    }

    func setStatusStyle(_ style: MenuBarStatusStyle) {
        statusStyle = style
        settingsStore.set(style.rawValue, for: .menuBarStatusStyle)
    }

    func setMenuBarEnabled(_ isEnabled: Bool) {
        isMenuBarEnabled = isEnabled
        settingsStore.set(isEnabled, for: .menuBarEnabled)

        // Turning the status item off while the Dock icon is hidden would leave the app with no
        // way back on screen at all — no icon, no menu bar, and a window the user may have
        // closed. The pairing is enforced here rather than in the view, so it holds however the
        // preference is reached.
        if !isEnabled, isMenuBarOnly {
            setMenuBarOnly(false)
        }
    }

    func setMenuBarOnly(_ isOnly: Bool) {
        isMenuBarOnly = isOnly
        settingsStore.set(isOnly, for: .menuBarOnly)
    }
}
