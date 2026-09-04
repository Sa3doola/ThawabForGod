//
//  AdhkarCoordinator.swift
//  ThawabForGod
//

import Observation

/// Owns which chapter the reader has open, and nothing else.
///
/// No `NavigationPath` here, deliberately — the adhkar tab's own `NavigationStack` is put up
/// once by `MainTabView`, and a second path would mean a `NavigationStack` nested inside that
/// one, which breaks the back gesture and the toolbar both. What this holds is the one piece of
/// state that decides whether the reading screen is on top: the list drives it through
/// `navigationDestination(item:)`, so a push and a back swipe are the same value changing.
///
/// **A slug rather than an `AdhkarCategory`.** The chapters are corpus rows now, and a deep link
/// or a saved shortcut carries a string — so holding the value would mean every route into this
/// screen had to resolve it first, in as many places as there are routes. Holding the id means
/// the reading screen resolves it once, and a slug the corpus has never heard of is a screen that
/// says so rather than a link that cannot be represented.
///
/// The same division as `QiblaCoordinator`: the coordinator knows which screen, the view model
/// knows what is on it.
@Observable
@MainActor
final class AdhkarCoordinator {

    /// The chapter being read, by slug, or `nil` at the list.
    private(set) var openCategoryID: String?

    func open(_ category: AdhkarCategory) {
        openCategoryID = category.id
    }

    func open(categoryID: String) {
        openCategoryID = categoryID
    }

    func closeCategory() {
        openCategoryID = nil
    }
}
