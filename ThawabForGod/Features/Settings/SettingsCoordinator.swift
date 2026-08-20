//
//  SettingsCoordinator.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Owns where Settings is, and nothing else.
///
/// A `NavigationPath` now, where a single optional destination used to do. The reason is `about`:
/// it opens a screen that itself opens the sources list, and a one-value destination cannot
/// express two levels. The path also means a back swipe, a Back button and a programmatic pop are
/// the same operation.
///
/// It still puts up no stack of its own. On iOS this screen is the root of the settings tab's,
/// and on macOS it is inside the one the `Settings` scene provides — a `NavigationStack` here
/// would be nested inside either, which breaks the back gesture and the toolbar both.
@Observable
@MainActor
final class SettingsCoordinator {

    var path = NavigationPath()

    func show(_ route: SettingsRoute) {
        path.append(route)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
