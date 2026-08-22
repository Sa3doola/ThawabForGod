//
//  QuickActionsService.swift
//  ThawabForGod
//

#if os(iOS)
import UIKit

/// Puts the quick actions on the app icon, and reads back the one that was tapped.
///
/// Both halves live together because they share the encoding: an action is carried to the system
/// as its `DeepLink` URL and comes back as the same string. That is one mechanism rather than
/// two, and it is the durable one — iOS caches shortcut items across launches, so an action the
/// reader taps today may have been registered by a build that no longer exists. A URL is this
/// app's promise about what a destination means (see `DeepLink`); a case name is not.
///
/// Titles are resolved *here*, at registration time, not at tap time — the system stores the
/// finished string. So a language change has to re-register. It does, for free: changing the
/// language relaunches the process, and registration runs on the way in.
@MainActor
struct QuickActionsService {

    private let localization: LocalizationManager

    init(localization: LocalizationManager) {
        self.localization = localization
    }

    /// Replaces the app icon's menu with `AppQuickAction.visible`.
    ///
    /// A whole-list assignment rather than an append: the list is derived from the enum every
    /// time, so it cannot drift from what the code says, and an action removed in an update
    /// disappears rather than lingering in whatever the system last cached.
    func register() {
        UIApplication.shared.shortcutItems = AppQuickAction.visible.map { action in
            UIApplicationShortcutItem(
                type: action.link.url.absoluteString,
                localizedTitle: localization.string(action.titleKey),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: action.symbol),
                userInfo: nil
            )
        }
    }

    /// The destination a tapped shortcut item's type names, or `nil` if it names nothing this
    /// build understands.
    ///
    /// Takes the `type` string rather than the item, so the scene delegate can call it without
    /// carrying a non-`Sendable` UIKit object across an isolation boundary.
    ///
    /// `nonisolated static` because it is a pure decode with nothing to be isolated to.
    nonisolated static func link(forType type: String) -> DeepLink? {
        guard let url = URL(string: type) else { return nil }
        return DeepLink(url: url)
    }
}
#endif
