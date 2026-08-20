//
//  HomeCoordinator.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Owns Home's navigation state, and nothing else.
///
/// It renders no views and holds no business logic — that separation is what lets a later
/// slice push a prayer detail by adding a case to `Destination`, without reaching into
/// `HomeView`.
///
/// The stack this drives is Home's *tab*, not the app's. Adhkar and Settings used to be cases
/// here and are now tabs of their own — see `AppTab` for where that line falls.
@Observable
@MainActor
final class HomeCoordinator {

    /// Where Home can go. `Hashable` because that is what `NavigationPath` stores and what
    /// `navigationDestination(for:)` matches on.
    enum Destination: Hashable {
        case qibla
        case tasbih
        case names
        /// Arranging Home itself, reached from the shortcuts section's own header. Settings
        /// pushes the same screen onto its own stack — two doors to a screen that edits what is
        /// on the other side of one of them, which is the case where a second door earns itself.
        case customize
    }

    var path = NavigationPath()

    /// Whether the day sheet is up.
    ///
    /// A sheet rather than a destination, and so a flag rather than a case: it is a *look* at the
    /// day the user is already on, not a place they navigate to and come back from — the same
    /// distinction `QuranCoordinator` draws for its reading panel.
    var isShowingPrayerTimes = false

    func show(_ destination: Destination) {
        path.append(destination)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
