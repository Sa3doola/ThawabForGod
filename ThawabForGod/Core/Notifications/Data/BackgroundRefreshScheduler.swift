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
/// `BGTaskScheduler.register(forTaskWithIdentifier:...)` **crashes at launch** if the
/// identifier is not declared there, so do this before running a build that reaches
/// `AppContainer.init()` with this scheduler wired in.
///
/// `@unchecked Sendable`: every stored property is `let`, and the one place a reference
/// crosses off the main actor — the system's launch handler, invoked on a queue of its own
/// choosing — only ever uses it to hop straight back onto `@MainActor` before touching
/// anything. The same shape `SpyOnboardingRepository` and `RecordingPrayerTimeRepository`
/// document as safe in the test target, applied here to a production type instead.
@MainActor
final class BackgroundRefreshScheduler: @unchecked Sendable {
    /// Namespaced under the bundle identifier, the way `PrayerReminder`'s own stable
    /// identifiers are — this is the string that must match Xcode's permitted-identifiers list.
    static let taskIdentifier = "com.Sa3dola.ThawabForGod.refreshReminders"

    private let notificationService: any NotificationService

    init(notificationService: any NotificationService) {
        self.notificationService = notificationService
    }

    /// Registers the launch handler. Must run before the app finishes launching — called from
    /// `AppContainer.init()`, the same "before any view exists" spot that configures TipKit,
    /// and for the same reason: registering any later than that is what the system fatals on.
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [self] task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self.run(appRefreshTask)
            }
        }
    }

    /// Submits the next request. Idempotent — the system replaces any pending request under the
    /// same identifier — so `RootView` can call this after every foreground refill without
    /// worrying about doubling up.
    func scheduleNextRefresh() {
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
        task.expirationHandler = { workTask.cancel() }

        await workTask.value
        task.setTaskCompleted(success: !workTask.isCancelled)
    }
}
#endif
