//
//  AppearanceSettingsViewModel.swift
//  ThawabForGod
//

import Observation

/// The accent, the light/dark choice, and the Home Screen icon.
///
/// **It stores nothing.** Both preferences already belong to `ThemeManager`, which persists them
/// through `SettingsStore` and is applied once at the root — so this forwards rather than mirrors.
/// A second copy of the accent living here would be a second source of truth, and the two would
/// drift the first time anything else changed one.
///
/// That is also why the properties are computed with setters rather than stored: reading one
/// inside a view registers an observation dependency on the *owner*, so a picker bound to it both
/// writes through and re-renders when anything else changes it.
///
/// The icon is the one exception, and only in form. Its owner is the system, which remembers it
/// across launches — but `UIApplication.alternateIconName` is not observable, so `appIcon` is a
/// mirror of it, read once when the screen's model is built and updated only by this type, which
/// is the only thing in the app that changes it.
@Observable
@MainActor
final class AppearanceSettingsViewModel {
    @ObservationIgnored private let theme: ThemeManager
    @ObservationIgnored private let appIcons: (any AppIconSwitching)?

    /// The icon on the Home Screen, as far as this screen knows.
    private(set) var appIcon: AppIconChoice

    /// `true` while iOS is changing the icon — the tiles are disabled so a second tap cannot race
    /// the first.
    private(set) var isChangingIcon = false

    /// Set when iOS refused a change. Settable so the alert can dismiss itself.
    var iconChangeFailed = false

    /// - Parameter appIcons: `nil` where the platform has no alternate icons — the Mac.
    init(theme: ThemeManager, appIcons: (any AppIconSwitching)?) {
        self.theme = theme
        self.appIcons = appIcons
        appIcon = AppIconChoice(alternateIconName: appIcons?.currentAlternateIconName)
    }

    var accent: AccentPalette {
        get { theme.accent }
        set { theme.select(accent: newValue) }
    }

    var appearance: AppearanceOverride {
        get { theme.appearance }
        set { theme.select(appearance: newValue) }
    }

    /// The icons to offer. Empty where the icon cannot be changed, which is how the screen knows
    /// to draw no section at all rather than four tiles that do nothing.
    var iconChoices: [AppIconChoice] {
        guard let appIcons, appIcons.supportsAlternateIcons else { return [] }
        return AppIconChoice.allCases
    }

    /// Asks iOS for `choice`, and puts the selection back if it says no.
    ///
    /// The selection moves *before* the call rather than after it. iOS confirms with an alert of
    /// its own, and a tile that waited for that alert to be dismissed before showing it had been
    /// chosen would look, for that whole time, like a tap that did not register.
    func selectIcon(_ choice: AppIconChoice) async {
        guard let appIcons, choice != appIcon, !isChangingIcon else { return }

        let previous = appIcon
        appIcon = choice
        isChangingIcon = true
        defer { isChangingIcon = false }

        do {
            try await appIcons.setAlternateIconName(choice.alternateIconName)
        } catch {
            appIcon = previous
            iconChangeFailed = true
        }
    }
}
