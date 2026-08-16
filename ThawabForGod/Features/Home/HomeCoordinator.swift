//
//  HomeCoordinator.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Owns Home's navigation state, and nothing else.
///
/// It renders no views and holds no business logic — that separation is what lets a later
/// slice push a prayer detail or a settings screen by adding a case here, without reaching
/// into `HomeView`.
///
/// The stack is empty today because Home has nowhere to go yet. Kept as a real type rather
/// than deferred, so the seam exists before the first destination needs it.
@Observable
@MainActor
final class HomeCoordinator {
    var path = NavigationPath()

    func popToRoot() {
        path = NavigationPath()
    }
}
