# Whole-codebase review — 2026-10-21

Branch `Development`. Five passes: four area reviews by subagents (Quran reader, concurrency and persistence, shared/cross-process code, navigation and routing) plus a convention sweep done with greps.

**Caveat:** every reviewer read the code without building or running it. None of the findings below has been re-verified by hand. Confidence is the reviewer's own. #5 was found independently by two reviewers.

## Ranked findings

| # | Severity | Area | Where | Issue |
|---|---|---|---|---|
| 1 | Medium | Data loss | `Core/PrayerTracker/Domain/PrayerTrackerUseCase.swift:34-39` | `setCompleted` reads, then saves, in two actor hops. Tapping two prayers quickly can overwrite the first, so Fajr silently un-logs. `try?` in `HomeViewModel.setPrayerCompleted` and `PrayerTimesSheetViewModel.setCompleted` hides the error. Fix: one repository method that upserts inside the actor. |
| 2 | Medium | Prayer logic | `Shared/Widgets/Domain/NextPrayerTimeline.swift:124`, `Features/MenuBar/MenuBarPanelViewModel.swift:73`, `NoorWidgets/Views/Support/PrayerList.swift:79` | `current` is `nil` after Isha and from midnight to Fajr, so Isha's window is never "open" and the menu-bar "log the open prayer" row vanishes when people pray Isha. Between sunrise and Dhuhr `current` is sunrise, which is not obligatory, so the widget list highlights nothing. Needs yesterday's Isha or a fallback. |
| 3 | Medium | Quran (Mac) | `Features/Quran/Commands/QuranCommand.swift:136,141-146,164` | `current = selectedAyah ?? location`, and the selection is never cleared. After tapping 2:255 and scrolling to surah 3, ⌘] reopens surah 3, ⌘D bookmarks 2:255, and in separated mode ←/→ jump from 2:255. Fix: use `reader.location` for stepping and paging, the selection only for panel and bookmark commands and only when on screen. |
| 4 | Medium | Quran (curl) | `Features/Quran/Mushaf/MushafCurlPlatform.swift:244,252,352` | `handedOut` is cleared only in `didFinishAnimating` (gesture turns). Go to, ⌘[ ⌘], keys, buttons and search never clear it, so the host pool grows past `poolLimit` toward 604 hosting controllers. Fix: clear it in `turnEnded()` and after the non-animated `setViewControllers`. |
| 5 | Medium | Quran data | `Features/Quran/QuranUserDataStore.swift:258-285` | After a failed write, `reloadFromDisk()` awaits `marks()` while the main actor is free. An edit made then is applied to memory, and `replace(with:)` overwrites it with the older snapshot. The write succeeds on disk, so it reappears next launch. Fix: re-check `linksInFlight` after the await and drop the snapshot if a write was enqueued. |
| 6 | Medium | Data loss | `QuranReaderView.swift:83-88`, `TasbihCounterView.swift:104`, `TasbihViewModel.swift:183-203` | No `beginBackgroundTask` anywhere. Exit-time writes are plain Task chains, so a kill mid-chain can lose the reading position or a tasbih mid-lap count. Tasbih awaits `activity.flush()` before saving the count; save the count first. |
| 7 | Medium | Reminders | `Core/Notifications/Data/UserNotificationService.swift:112`, `App/RootView.swift:47-52` | Refreshes are not serialized and the add loop ignores cancellation. An old run can overwrite a newer plan (stable identifiers, `add` replaces). The foreground refill and the background task can collide the same way. Fix: serialize, or check `Task.isCancelled` in the loop. |
| 8 | Medium | Navigation | `App/AppContainer+Routing.swift:22-32` | `.qibla`, `.tasbih` and `.names` append to Home's path with no `popToRoot()` or already-on-top check. A second `noor://qibla` stacks two Qiblas, and `noor://names` on Tasbih stacks Names over it. |
| 9 | Medium | macOS | `App/RootView.swift:63`, `ThawabForGodApp.swift:40` | A `noor://` widget tap on a Mac likely opens a new `WindowGroup` window sharing one `AppContainer`. Two live stacks drive the same coordinator paths and fight each other. Fix: `.handlesExternalEvents(matching:)` or a single `Window` scene. |
| 10 | Medium | Performance | `App/AppContainer.swift:345,393,443,512,521,535` | `@ModelActor` repositories are built on the main actor. On iOS 17 this may bind their `ModelContext` to the main queue, putting fetches and saves on the main thread. Widely reported, unconfirmed on the current SDK. |
| 11 | Medium | Navigation | `App/AppContainer.swift:599`, `App/QuickActions/AppSceneDelegate.swift:103-107` | A cold-launch quick action is dropped if `AppContainer.init` runs after `scene(_:willConnectTo:)`, because `DeepLinkInbox.current` is still `nil`. The ordering is unconfirmed. Fix: keep a static pending link and flush it from `makeCurrent`. |
| 12 | Medium | Navigation | `Features/Home/HomeCoordinator.swift:51`, `TasbihCoordinator.swift:20-24`, `NamesCoordinator.swift` | `popToRoot()` does not reset the nested `openDhikr` / `openName` items, so the next Tasbih visit may push the old counter straight away. Fix: reset sub-coordinators when Home pops. |
| 13 | Low-medium | Widgets | `WidgetRefreshing.reloadAll` callers, `reminderKey` | Widgets are not reloaded when digits, clock format or accent change; the old style stays until the next foreground. |
| 14 | Low-medium | Hadith | `Features/Hadith/Domain/HadithProgressUseCase.swift:55-63`, `MemorizeHadithUseCase.swift:83-91` | Toggles read, then act, across actor hops. A double-tap runs two adds, so the narration ends up kept and the star shows "kept". Fix: `setBookmarked(Bool)` taking the desired state. |
| 15 | Low-medium | Tasbih | `Features/Tasbih/TasbihViewModel.swift` (`select` ~100-122, `reset` ~166-178) | Taps during the awaits are counted under the wrong preset or overwritten by the loaded session, and the dirty flag is cleared without a save. |
| 16 | Low-medium | Activity | `Core/Activity/UI/ActivityRecorder.swift:47-65` | `flush()` returns at once while a write is in flight, so Home can reload and show the old recent-activity chip. |
| 17 | Low-medium | Navigation | `App/AppContainer+DeepLink.swift:56-57,69-71`, `+Routing.swift:47-49` | `DeepLink.quran` is documented as "wherever reading stopped" but maps to `AppRoute.quran`, which pops to the Library. `.hadith` pops the same way. `AppRoute.quranContinue` is unreachable from any link. |
| 18 | Low-medium | macOS | `Features/MenuBar/MenuBarController.swift:204` | Free-width estimate mixes global screen coordinates with a width. With a display left of the primary, automatic style can pin to symbol-only. Fix: measure relative to the window's screen. |
| 19 | Low | Reminders | `UserNotificationService.swift:187` | Triggers are wall-clock components with no time zone. After travelling with the app closed they fire at the old zone's hour for up to 10 days. |
| 20 | Low | Reminders | `Core/Notifications/Data/AppReminderInputs.swift:44`, `BackgroundRefreshScheduler.run` | A background refresh can hang on `currentCoordinates()`, because cancellation does not resume the continuation; the task is killed and the window not refilled. |
| 21 | Low | Reminders | `BackgroundRefreshScheduler.swift` (~130-140) | `setTaskCompleted(success: !isCancelled)` reports success even if the refill failed. |
| 22 | Low | Quran | `Mushaf/MushafPagerView.swift:204-217,180` | A swipe within the 500 ms jump window is dropped and the pager snaps back. Two jumps to one target share `jumpTarget`, so the earlier expiry shortens the later window. |
| 23 | Low | Quran | `Mushaf/MushafPagerView.swift:169-189` | On spread-to-single (rotation or fold), stale `visibleUnit` can land the reader on page 3 instead of 4 and record it as the reading position. Timing-dependent. |
| 24 | Low | Quran | `AyahPanel/AyahPanel.swift:146,318,~367` | `didCopy` resets only on an ayah or pack change, so a second Copy shows "Copied" with no haptic. |
| 25 | Low | Quran | `Commands/QuranKeyInput.swift:140-146 (Mac), 87-91 (iOS)` | Space and the arrows are claimed even when a side-panel control has focus. The iOS responder can stay first responder after a section switch. |
| 26 | Low | Hadith | `Features/Hadith/HadithViewModel.swift` (~331) | `recordLastRead` overwrites `pendingWrite` without chaining, and `try?` swallows failures. The earlier kitab could be saved as last read. |
| 27 | Low | Navigation | `Features/Quran/QuranCoordinator.swift:226-229` | The cold-launch rollback sets `path = []` unconditionally, wiping a stack the user has built. Should only pop when `path == [.reader]`. |
| 28 | Low | Navigation | `App/RootView.swift:70-73` | Doc comment says links during onboarding are dropped, but quick actions are queued and open a section when onboarding ends. URL links are dropped, so the two paths are inconsistent. |
| 29 | Low | Dates | `Shared/Widgets/Domain/DailyAyahRule.swift:24` | Uses `.current` where every other builder uses `.autoupdatingCurrent`; after a zone change the app and widget can disagree on the day. |
| 30 | Low | Config | `Shared/Settings/Data/SharedDefaults.swift:30`, three `.entitlements` files | `CLAUDE.md` says the App Group identifier differs per platform with a Team ID prefix on macOS, but code and entitlements use one plain `group.com.Sa3dola.ThawabForGod`. Check on a signed Mac build, or fix the doc. |
| 31 | Low | Performance | `Core/Persistence/Corpus/CorpusDatabase.swift`, `Features/Quran/Data/QuranAyahIndex.swift` | Synchronous first open of the 24 MB hadith file, and a 6,236-row read under a lock. Can hitch if a main-actor caller reaches them first. |

**Navigation, low confidence, needs a device check:** `Features/Adhkar/AdhkarCoordinator.swift:29` and `App/AppSectionView.swift:166-172`. Adhkar is the one section with no bound path. On iOS 17 a destination that is non-nil at first appearance may not push, so `noor://adhkar?period=morning` may land on the list.

## Convention sweep

- `Features/Calendar/Views/MoonView.swift:190,197`: English-only `Text(verbatim:)` strings ("Northern" / "Southern"), a hardcoded `.white`, and a system `.font(.caption2)`. Will break Arabic.
- `Features/Home/Views/Sections/ContinueReadingSection.swift:45` and `IslamicCalendarSection`: bare `.padding()` where sibling cards use `AppSpacing` tokens (the earlier `/code-review` finding).
- One system `.font(.caption…)` each in `OnboardingScaffold.swift`, `Shared/Widgets/UI/QuranContinueReadingContent.swift` and `Shared/Theming/UI/ThemeEnvironment.swift`. Not read, may be justified.
- Likely fine: `Core/Notifications/Data/ReminderArtwork.swift:148` (`.font(.system(size:))`, rendered to an image) and `Features/Calendar/Scene/MoonScene.swift:63` (platform `gray` for the moon material).

## Checked and clean

- Quran hard rules: no violations of text-never-altered, no `.inspector`, no tap-to-turn; `QuranReaderView.body` reads are the documented exceptions.
- Persistence: all 10 `@Model` classes are in `PersistenceController.schema`; no data races in `FontPackStore`, `PageMetricsCache`, `CorpusDatabase`, `QuranAyahIndex` or `ResolveOccasionDatesUseCase`; no lock-order cycle.
- Navigation: `DeepLink`, `AppRoute`, `AppTab` and `AppSectionView` switches are exhaustive; the `.id(selectedTab)` and `navigationPath(isActive:)` design holds.
- Shared code: no `Shared/` import violations (it also uses CoreGraphics, CoreText and os, which are system frameworks with no dependency cost); widget kind strings unchanged; `NextPrayerTimeline`, `HijriDateTimeline`, `PrayerReminderPlanner` (window, ids, 64 cap), artwork copy-per-request, `SettingsGroupMigration`, `DeepLink` round trip, `ReminderPresentation` decode, `QuranWidgetTimeline` trimming and `HijriCalendarService` offsets all held up.
- Greps found no `UserDefaults.standard` use in code, `NavigationLink(value:)`, `.inspector`, `ObservableObject`/`@Published`, `AnyView`, or UI/SwiftData/GRDB imports in Domain.
- Quran reader maths: `JustifiedLineLayout`, the spread and RTL gutter, ribbon alignment, `QuranAyahText` range mapping, position debounce and flush ordering, and `AyahPanelViewModel` stale-result guards.

## Suggested order of work

1. #1 and #5: small, concrete, user-visible data loss.
2. #3 and #4: Quran Mac commands and curl-pool growth.
3. #2: a product-logic decision about what "current prayer" means after Isha.
4. Confirm #10 and #11 (both marked unconfirmed) before spending time on them.
