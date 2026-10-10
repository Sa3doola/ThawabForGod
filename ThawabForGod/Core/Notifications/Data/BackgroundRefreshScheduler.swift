//
//  BackgroundRefreshScheduler.swift
//  ThawabForGod
//

#if os(iOS)
import BackgroundTasks
import Foundation

/// Registers and submits the background task that refills the reminder window while the app
/// is not open.
///
/// `RootView`'s two triggers — `.task(id:)` and `.onChange(of: scenePhase)` returning to
/// `.active` — only run while the app is open. Ten days of headroom absorbs any ordinary gap
/// between launches, but a phone left untouched for longer runs the window dry, which is the
/// gap the TODO at the foot of `UserNotificationService` used to describe. This is the fix:
/// every successful foreground refill also books a `BGAppRefreshTaskRequest`, so the system
/// wakes the app to refill again even if it is never opened.
///
/// iOS only. Background App Refresh is not a concept `macOS` shares this way, and there is
/// nothing for a Mac build to register.
///
/// **Needs a one-time Xcode step this type cannot perform on its own.** This project's
/// Info.plist is generated from build settings (`GENERATE_INFOPLIST_FILE = YES`, see
/// `ThawabForGod.xcodeproj`), and `CLAUDE.md` asks that `project.pbxproj` never be hand-edited.
/// Declaring `Self.taskIdentifier` under `BGTaskSchedulerPermittedIdentifiers` therefore has to
/// go through Xcode's UI:
///   1. Select the `ThawabForGod` target → **Signing & Capabilities** → **+ Capability** →
///      **Background Modes** → check **Background fetch**.
///   2. Still on that tab, add a **Permitted background task scheduler identifiers** entry (or,
///      if Xcode only offers the raw key, add `BGTaskSchedulerPermittedIdentifiers` as an array
///      containing `"\(Self.taskIdentifier)"` under **Info** → **Custom iOS Target Properties**).
/// `BGTaskScheduler.register(forTaskWithIdentifier:...)` returns `false` if the identifier is not
/// declared there, and `registerLaunchHandler()` asserts on that in DEBUG, so do this before
/// running a build that reaches `AppDelegate.application(_:didFinishLaunchingWithOptions:)`,
/// which is where the handler is registered. In Release the `false` is silent. The fatal case
/// is different: registering after launch has finished, or registering the same identifier
/// twice, is an error the system treats as fatal.
@MainActor
final class BackgroundRefreshScheduler {
    /// Namespaced under the bundle identifier, the way `PrayerReminder`'s own stable
    /// identifiers are — this is the string that must match Xcode's permitted-identifiers list.
    static let taskIdentifier = "com.Sa3dola.ThawabForGod.refreshReminders"

    private let notificationService: any NotificationService

    init(notificationService: any NotificationService) {
        self.notificationService = notificationService
    }

    /// The scheduler the launch handler runs. Published by `AppContainer`, read when a task fires.
    ///
    /// Registration and the instance are separate on purpose. The system wants the handler
    /// registered before launch finishes, and the container that owns this scheduler may not be
    /// built by then, so the handler looks the scheduler up when a task arrives instead of
    /// capturing one.
    private(set) static var current: BackgroundRefreshScheduler?

    /// Publishes `scheduler` as the one the launch handler runs. Only the composition root calls
    /// this, and it skips the call in tests so a test's container is never the target of the
    /// host app's handler.
    static func makeCurrent(_ scheduler: BackgroundRefreshScheduler) {
        current = scheduler
    }

    /// Registers the launch handler. Called once, from
    /// `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, which is the window the
    /// system documents: `BGTaskScheduler` requires every launch handler to be registered before
    /// the end of `applicationDidFinishLaunching`, and fatals on any later one.
    ///
    /// It must not depend on when `AppContainer` is built. With the current toolchain the
    /// container can be built as late as the first scene's connection, which was observed to fall
    /// after launch had finished, and registering from there was an intermittent launch crash.
    ///
    /// The block captures nothing. It runs on a queue of the system's choosing, so it hops to the
    /// main actor and reads `current` there. It is `@Sendable` because the SDK does not say so
    /// for it: written inside a main-actor function, an unannotated closure is taken to be
    /// main-actor code as well, which is untrue of a block the system calls on its own queue.
    static func registerLaunchHandler() {
        // `false` means the identifier is missing from `BGTaskSchedulerPermittedIdentifiers`.
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { @Sendable task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                // No container has published a scheduler, for instance a background launch that
                // connected no scene. The work did not happen, so say so rather than leave the
                // task open, but book the next attempt first so the chain does not end here.
                guard let scheduler = BackgroundRefreshScheduler.current else {
                    BackgroundRefreshScheduler.scheduleNextRefresh()
                    appRefreshTask.setTaskCompleted(success: false)
                    return
                }
                await scheduler.run(appRefreshTask)
            }
        }
        assert(
            registered,
            "Could not register \(taskIdentifier): add it to BGTaskSchedulerPermittedIdentifiers."
        )
    }

    /// The instance form, kept because `RootView` and `run(_:)` call it on a scheduler. It
    /// delegates because the launch handler needs to book a refresh when no instance exists.
    func scheduleNextRefresh() {
        Self.scheduleNextRefresh()
    }

    /// Submits the next request. Idempotent — the system replaces any pending request under the
    /// same identifier — so it can be called after every foreground refill, as `RootView` does
    /// through the instance form, without worrying about doubling up.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        // A day out. The rolling window has ten days of headroom, so nothing is gained by
        // asking more often — and the system only ever honours this as a lower bound anyway,
        // waking the app when it judges the moment worth the battery.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)

        // Can fail — too many pending requests, or the system declining for its own reasons —
        // and there is nothing more useful to do about it than let the existing pending
        // request, if any, stand.
        try? BGTaskScheduler.shared.submit(request)
    }

    private func run(_ task: BGAppRefreshTask) async {
        // Requested again immediately, before the work starts: if the system terminates the
        // app mid-refresh, the next window is still on the books rather than lost with it.
        scheduleNextRefresh()

        let workTask = Task { await notificationService.refreshSchedule() }
        // `@Sendable` for the reason the launch block is: the system may call this on a thread
        // of its own, and an unannotated closure here would be inferred main-actor code.
        task.expirationHandler = { @Sendable in workTask.cancel() }

        await workTask.value
        task.setTaskCompleted(success: !workTask.isCancelled)
    }
}
#endif
