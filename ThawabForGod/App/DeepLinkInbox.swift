//
//  DeepLinkInbox.swift
//  ThawabForGod
//

import Observation

/// One link, waiting to be opened.
///
/// It exists because of *when* a quick action arrives rather than what it is. A tap on a Home
/// Screen shortcut reaches `AppSceneDelegate` — a class UIKit constructs itself, from a
/// configuration, with no argument list to inject anything through — and it can reach it before
/// `RootView` has a body. So the delegate does not route; it drops the link here, and the view
/// picks it up whenever it is ready, whether that is in a moment or immediately.
///
/// That also keeps the routing rule intact. `AppContainer.open(_:)` stays the only thing that
/// knows how to move between sections; this type knows nothing except that a link is pending.
///
/// `@Observable` so `RootView` can watch `pending` with `onChange(of:initial:)` — the `initial`
/// is what covers the cold-launch case, where the link was posted before the view existed and no
/// *change* will ever be observed.
@Observable
@MainActor
final class DeepLinkInbox {

    private(set) var pending: DeepLink?

    /// The instance the scene delegate posts to.
    ///
    /// The one static in the app's routing, and it is here rather than anywhere else because
    /// UIKit owns the scene delegate's lifetime and hands it no dependencies. `AppContainer`
    /// still *owns* the inbox — this only publishes which one is live, and only the composition
    /// root ever writes it.
    private(set) static var current: DeepLinkInbox?

    init() {}

    /// Makes this the inbox the scene delegate posts to. Called once, by `AppContainer`.
    static func makeCurrent(_ inbox: DeepLinkInbox) {
        current = inbox
    }

    func receive(_ link: DeepLink) {
        pending = link
    }

    /// Takes the pending link, leaving the inbox empty.
    ///
    /// Consuming rather than reading is what stops the same link being opened twice — once when
    /// it arrives and again the next time anything else causes the observer to re-evaluate.
    func consume() -> DeepLink? {
        defer { pending = nil }
        return pending
    }
}
