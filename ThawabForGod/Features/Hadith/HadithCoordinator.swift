//
//  HadithCoordinator.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Owns where the hadith tab is, and nothing else.
///
/// A typed path rather than the pair of optionals this started as, and for the reason
/// `SettingsCoordinator` has one: the stack is genuinely two pushes deep — a collection is
/// divided into kitab and a kitab holds the narrations — and **a search result has to arrive at
/// the bottom of it in one move.** Chained `navigationDestination(item:)` cannot do that: the
/// second destination is declared by the first destination's view, which does not exist until the
/// first push has happened, so setting both in one update pushes one level and drops the other.
/// Appending two routes to a path is one update that lands both.
///
/// `[HadithRoute]` rather than `NavigationPath`, unlike Settings. The array is `Equatable`, which
/// is what lets the reading screen key its `.task(id:)` on where the stack actually is, and the
/// type erasure `NavigationPath` buys is worth nothing when every destination is one enum.
///
/// It still puts up no stack of its own: `MainTabView` owns the tab's, and a second here would be
/// nested inside it, which breaks the back gesture and the toolbar both.
@Observable
@MainActor
final class HadithCoordinator {

    var path: [HadithRoute] = []

    /// Which narration the reading screen should scroll to, or `nil` to start at the top.
    ///
    /// Held here rather than inside the route because it is not part of *what* is open: two
    /// search results in the same kitab open the same screen, and folding the narration into the
    /// route would make them two destinations and push twice. It is also consumed once — the
    /// reader scrolls afterwards, and a target that outlived the scroll would drag them back to
    /// it on the next redraw. The same reasoning as `QuranCoordinator.scrollTarget`.
    private(set) var scrollTarget: HadithID?

    func open(_ collection: HadithCollection) {
        path = [.collection(collection)]
        scrollTarget = nil
    }

    func open(_ book: BookReference) {
        path.append(.book(book))
        scrollTarget = nil
    }

    /// Moves the reader to the kitab beside the one they are in, **without deepening the stack**.
    ///
    /// The footer's two buttons are a way through a collection, not a way further into it: a
    /// reader who pages through six divisions and then goes back means the list they started
    /// from, and `append` would give them six taps of Back through kitab they have already
    /// finished. So the top of the path is replaced rather than pushed onto.
    func page(to book: BookReference) {
        guard !path.isEmpty else { return }

        path[path.count - 1] = .book(book)
        scrollTarget = nil
    }

    /// Opens the kitab a narration belongs to, positioned at it — how a search result and, later,
    /// a bookmark both get back into the text.
    ///
    /// Takes the collection as well as the narration because a `Hadith` carries only its
    /// collection's id, and the screen above wants the name to put in the title bar. The caller
    /// has the value in hand: search happens on the screen that loaded the collections.
    func open(_ hadith: Hadith, in collection: HadithCollection) {
        path = [
            .collection(collection),
            .book(BookReference(collection: hadith.collectionID, number: hadith.bookNumber))
        ]
        scrollTarget = hadith.id
    }

    /// Called by the reading screen once it has scrolled. See `scrollTarget`.
    func clearScrollTarget() {
        scrollTarget = nil
    }

    func memorize() {
        path = [.memorize]
        scrollTarget = nil
    }

    func popToRoot() {
        path = []
        scrollTarget = nil
    }
}

/// The two screens the hadith tab can push, as one type.
///
/// A `HadithCollection` travels whole where a `BookReference` is only a reference, and the
/// asymmetry is deliberate: the divisions screen needs the collection's name for its title and
/// has it in hand from the list that pushed it, while the reading screen is reachable from a
/// search result that never loaded the kitab and has to fetch it anyway.
nonisolated enum HadithRoute: Hashable, Sendable {
    case collection(HadithCollection)
    case book(BookReference)
    /// The review session. Carries nothing: what is due is a question for the store, asked when
    /// the screen appears, not something the row that opened it could have known.
    case memorize
}
