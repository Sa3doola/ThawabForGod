//
//  AppIconSwitching.swift
//  ThawabForGod
//

import Foundation

/// The Home Screen icon, as the system holds it.
///
/// A protocol so Domain never imports UIKit and the view model is testable without a Home
/// Screen: the tests hand it a fake, and the app hands it `UIApplicationIconSwitcher`.
///
/// `@MainActor` because the one real implementation is `UIApplication`, which is.
@MainActor
protocol AppIconSwitching: AnyObject {
    /// Whether this process may change its icon at all. `false` on the Mac, which has no such
    /// API, and in any context iOS decides does not get one.
    var supportsAlternateIcons: Bool { get }

    /// The alternate icon in effect, or `nil` for the primary one.
    var currentAlternateIconName: String? { get }

    /// Changes the icon. iOS confirms the change with an alert of its own, which the app cannot
    /// suppress, and throws for a name its Info.plist does not list.
    func setAlternateIconName(_ name: String?) async throws
}
