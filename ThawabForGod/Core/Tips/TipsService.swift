//
//  TipsService.swift
//  ThawabForGod
//

import Foundation
import TipKit

/// Owns TipKit's datastore: configured once at launch, reset or invalidated on demand.
///
/// Unlike every other `Core` subsystem this one has no `Domain` / `Data` split, because there
/// is no framework-free contract to isolate: the protocol's vocabulary — `Tip`,
/// `Tips.InvalidationReason` — *is* TipKit's. Splitting it would produce a "Domain" folder
/// that imports a UI framework, which is worse than admitting the coupling here. Nothing above
/// this file needs the abstraction anyway: features define their own `Tip` values and the app
/// only ever asks this service to configure, reset, or invalidate.
@MainActor
protocol TipsServicing {
    /// Prepares the tip datastore. Called once, from the composition root, before any view
    /// that carries a tip is built.
    func configure()

    /// Wipes every recorded display, donation and parameter. For a "reset tips" action in
    /// Settings, and for tests that need a clean datastore.
    func resetAll()

    /// Retires a tip so it never shows again.
    func invalidate(_ tip: any Tip, reason: Tips.InvalidationReason)
}

extension TipsServicing {
    /// The common case: the user did the thing the tip was pointing at.
    func invalidate(_ tip: any Tip) {
        invalidate(tip, reason: .actionPerformed)
    }
}

/// The TipKit-backed implementation.
///
/// `@MainActor` is stated rather than inherited from the module default because it is a real
/// claim about this type and not a convenience: it is driven from the composition root and from
/// views, its whole job is deciding what appears on screen, and it does no background work that
/// would want to leave the main actor. `Tips.configure` itself is `nonisolated`; pinning the
/// service is what keeps the one-shot flag below free of any synchronisation.
@MainActor
final class TipsService: TipsServicing {

    /// Whether `Tips.configure` has succeeded in this process.
    ///
    /// Static, because `Tips.configure` is a process-wide, one-shot call — a second
    /// `TipsService` (a preview, a test) must not call it again. Safe to hold as mutable
    /// static state precisely because the type is main-actor isolated.
    private(set) static var isConfigured = false

    private let datastoreURL: URL

    /// Application Support rather than Caches: a dismissed tip has to stay dismissed, and the
    /// system is free to evict Caches whenever it likes.
    ///
    /// `nonisolated` so it can serve as a default argument below — default arguments are
    /// evaluated at the call site, which is not guaranteed to be the main actor.
    nonisolated static var defaultDatastoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "Tips", directoryHint: .isDirectory)
    }

    /// `nonisolated` for the same reason as the default argument above: `AppContainer` names
    /// `TipsService()` as its own default, which is evaluated at the caller's isolation. The
    /// init only stores a URL, so there is nothing here that needs the main actor — and the
    /// instance it hands back is `Sendable` anyway, this type being `@MainActor`.
    nonisolated init(datastoreURL: URL = TipsService.defaultDatastoreURL) {
        self.datastoreURL = datastoreURL
    }

    func configure() {
        guard !Self.isConfigured else { return }

        do {
            // TipKit expects the directory to exist; it creates the store inside, not the
            // folder around it.
            try FileManager.default.createDirectory(
                at: datastoreURL,
                withIntermediateDirectories: true
            )
            try Tips.configure([
                // `.immediate` while the app has one tip. Once several ship, this becomes a
                // real pacing decision — `.daily` is the usual answer.
                .displayFrequency(.immediate),
                .datastoreLocation(.url(datastoreURL))
            ])
            Self.isConfigured = true
        } catch {
            // Deliberately swallowed. Tips are decoration: a datastore that cannot be opened
            // must cost the user a tip, never a launch. `isConfigured` stays false, so
            // `resetAll()` below knows not to talk to a store that was never opened.
        }
    }

    /// Wipes the store on disk — but measured on this SDK, **nothing observable changes until
    /// the next launch**: within the session that calls it, an invalidated tip still reports
    /// `.invalidated` and donated events still report their donations. TipKit means this to run
    /// *before* `Tips.configure`, which is the one moment a wiped store is actually read.
    ///
    /// So a "reset tips" action in Settings has to tell the user the change takes effect next
    /// launch, or the app has to reset at launch instead. Worth knowing before that screen is
    /// built, rather than discovering it as a bug report.
    func resetAll() {
        guard Self.isConfigured else { return }

        // Throws if the datastore is unreadable — the same "tips are decoration" reasoning
        // applies, so the failure is absorbed rather than propagated to the caller.
        try? Tips.resetDatastore()
    }

    func invalidate(_ tip: any Tip, reason: Tips.InvalidationReason) {
        tip.invalidate(reason: reason)
    }
}
