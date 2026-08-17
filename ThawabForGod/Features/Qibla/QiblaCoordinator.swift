//
//  QiblaCoordinator.swift
//  ThawabForGod
//

import Observation

/// Owns what the Qibla feature presents, and nothing else.
///
/// No `NavigationPath` here, unlike `HomeCoordinator`: Qibla has nothing to push to and an
/// empty stack would be a seam pretending to be in use. What it does own is the manual-location
/// sheet — the fallback a user reaches when location is refused, and the way anyone corrects a
/// position the app got wrong. Keeping that flag here rather than in `QiblaViewModel` is what
/// lets the view model stay about angles and the coordinator about screens.
@Observable
@MainActor
final class QiblaCoordinator {
    private(set) var isEditingLocation = false

    func editLocation() {
        isEditingLocation = true
    }

    func finishEditingLocation() {
        isEditingLocation = false
    }
}
