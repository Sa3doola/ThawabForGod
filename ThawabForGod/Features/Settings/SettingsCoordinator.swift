//
//  SettingsCoordinator.swift
//  ThawabForGod
//

import Observation

/// Owns which Settings sub-screen is open, and nothing else.
///
/// No `NavigationPath`, for the same reason `NamesCoordinator` has none: on iOS this screen is
/// the root of the settings tab's own stack, and a second path here would mean a
/// `NavigationStack` nested inside that one — which breaks the back gesture and the toolbar both.
/// A single value driving `navigationDestination(item:)` also works unchanged inside the stack
/// the macOS Settings scene puts up, so one mechanism covers both platforms.
@Observable
@MainActor
final class SettingsCoordinator {

    /// Where Settings can go.
    enum Destination: Hashable {
        case homeCustomization
        case sources
    }

    /// The open sub-screen, or `nil` at the settings list itself.
    private(set) var destination: Destination?

    func show(_ destination: Destination) {
        self.destination = destination
    }

    func close() {
        destination = nil
    }
}
