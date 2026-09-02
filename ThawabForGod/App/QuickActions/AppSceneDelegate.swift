//
//  AppSceneDelegate.swift
//  ThawabForGod
//

#if os(iOS)
import UIKit

/// The application object, present for one reason: quick actions do not arrive through
/// `onOpenURL`.
///
/// A widget tap is a URL and SwiftUI hands it straight to the view tree. A Home Screen shortcut
/// is not a URL as far as the system is concerned — it is a `UIApplicationShortcutItem` delivered
/// to a `UIWindowSceneDelegate`, and a SwiftUI app has no scene delegate unless it asks for one.
/// This is the ask.
///
/// Nothing else belongs here. The delegate supplies a scene configuration and stops; the
/// routing is `AppContainer.open(_:)`'s, as it is for every other way into the app.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = AppSceneDelegate.self
        return configuration
    }
}

/// Receives quick-action taps and posts them to `DeepLinkInbox`.
///
/// Two callbacks because there are two ways a shortcut arrives, and missing either one is a tap
/// that does nothing:
///
/// - **Cold launch** — the app was not running, and the item comes in the scene's connection
///   options. `RootView` does not exist yet at this point, which is exactly why the link is
///   parked in an inbox rather than routed.
/// - **Warm launch** — the app was already in the background, and the item is delivered on its
///   own.
///
/// It deliberately implements nothing else. SwiftUI still owns the window and the scene's
/// lifecycle; supplying a delegate class adds callbacks rather than taking anything over.
final class AppSceneDelegate: NSObject, UIWindowSceneDelegate {

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let item = connectionOptions.shortcutItem else { return }
        deliver(item.type)
    }

    /// The **completion-handler** form of the shortcut callback, deliberately, and not the
    /// `async` one Swift refines it into.
    ///
    /// The async form is what this was, and it aborted the app on every warm tap. Its `@objc`
    /// thunk wraps the body in a task and calls UIKit's completion block from wherever that task
    /// happens to finish; written `nonisolated`, that was the cooperative pool, and the block
    /// runs `-[UIApplication _performBlockAfterCATransactionCommitSynchronizes:]`, which asserts
    /// off the main thread. Cold launches never hit it because they arrive through
    /// `scene(_:willConnectTo:options:)` instead, which is why only one of the two ever crashed.
    ///
    /// Writing the witness `@MainActor` fixes the thread and costs a `Sendable` diagnostic —
    /// `UIApplicationShortcutItem` crossing from a `nonisolated` protocol requirement into
    /// main-actor code — which is an error under Swift 6. This form has neither problem: there
    /// is no task, so the completion is called synchronously on the thread UIKit called us on,
    /// and the selector is spelled out so it is dispatched whichever form the SDK refines.
    ///
    /// `assumeIsolated` rather than a hop, because UIKit calls scene delegates on the main
    /// thread and a hop would put the completion back on the wrong one.
    @objc(windowScene:performActionForShortcutItem:completionHandler:)
    nonisolated func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let type = shortcutItem.type
        completionHandler(MainActor.assumeIsolated { deliver(type) })
    }

    /// - Returns: whether the type named something this build could open, which is what the
    ///   warm-launch callback reports back to the system.
    @discardableResult
    private func deliver(_ type: String) -> Bool {
        guard let link = QuickActionsService.link(forType: type),
              let inbox = DeepLinkInbox.current else {
            return false
        }

        inbox.receive(link)
        return true
    }
}
#endif
