//
//  UIApplicationIconSwitcher.swift
//  ThawabForGod
//

#if os(iOS)
import UIKit

/// `AppIconSwitching` over `UIApplication`.
///
/// In the app target rather than `Shared/`: `UIApplication.shared` is unavailable in an app
/// extension, and everything in `Shared/` compiles into the widget too — the same reason
/// `keepScreenAwake(_:)` lives where it does.
///
/// iOS only. The Mac has no alternate-icon API: `NSApp.applicationIconImage` lasts only while the
/// app runs, and a sandboxed app cannot rewrite its own bundle. `AppContainer` hands the Mac build
/// no switcher, and the Appearance screen draws no section for it.
@MainActor
final class UIApplicationIconSwitcher: AppIconSwitching {
    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    var currentAlternateIconName: String? {
        UIApplication.shared.alternateIconName
    }

    func setAlternateIconName(_ name: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(name)
    }
}
#endif
