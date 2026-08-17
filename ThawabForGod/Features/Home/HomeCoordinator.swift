//
//  HomeCoordinator.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Owns Home's navigation state, and nothing else.
///
/// It renders no views and holds no business logic — that separation is what lets a later
/// slice push a prayer detail or a settings screen by adding a case to `Destination`, without
/// reaching into `HomeView`.
@Observable
@MainActor
final class HomeCoordinator {

    /// Where Home can go. `Hashable` because that is what `NavigationPath` stores and what
    /// `navigationDestination(for:)` matches on.
    enum Destination: Hashable {
        case qibla
        case adhkar
        case tasbih
        case names
        /// iOS and iPadOS only. On macOS, Settings is a scene of its own reached with ⌘, — the
        /// place a Mac user looks for it — rather than a screen pushed onto this stack.
        case settings
    }

    var path = NavigationPath()

    func show(_ destination: Destination) {
        path.append(destination)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
