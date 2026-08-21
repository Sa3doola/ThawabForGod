//
//  AppContainer.swift
//  ThawabForGod
//

import Foundation

/// Composition root. The only place concrete implementations are constructed — everything
/// else depends on protocols and receives them through init or the environment.
@MainActor
final class AppContainer {

    // MARK: Core

    let settingsStore: any SettingsStore
    let numberFormatting: any NumberFormattingService
    let timeFormatting: any TimeFormattingService
    let persistence: PersistenceController
    let themeManager: ThemeManager
    let localizationManager: LocalizationManager
    let bookmarkRepository: any BookmarkRepository
    let httpClient: any HTTPClient
    let locationService: any LocationService
    let headingProvider: any HeadingProviding

    /// The one part of the location story that needs the network. Held here rather than built
    /// inside Home so a later screen — the prayer-times sheet, a widget — shares the one cache
    /// rather than geocoding the same point again.
    let placeNameResolver: any PlaceNameResolving

    /// The time, and the heartbeat every countdown runs on. One instance, because a clock has no
    /// state worth duplicating and every screen should agree about what "now" is.
    let clock: any ClockService
    let notificationService: any NotificationService

    #if os(iOS)
    /// Refills the reminder window from the background. iOS only — see the type's own
    /// documentation for the manual Xcode capability step it depends on.
    let backgroundRefreshScheduler: BackgroundRefreshScheduler
    #endif

    /// Which prayers are reminded, as an observable the Settings screen edits and the refresh
    /// key watches. The scheduler itself re-reads the store rather than this object.
    let reminderPreferences: ReminderPreferences

    /// Where the user last got to, in each of the three things they can be in the middle of.
    /// Written by the Quran, the adhkar and the tasbih; read by Home.
    let recentActivityRepository: any RecentActivityRepositoring
    let recentActivity: RecentActivityUseCase

    /// The one recorder the three writers share, so a pending write from one cannot cancel a
    /// pending write from another — see the type's own note on why there is one per kind.
    let activityRecorder: ActivityRecorder

    let tipsService: any TipsServicing
    let hijriDates: any HijriDateServicing
    let reachability = ReachabilityMonitor()

    // MARK: Prayer times

    let prayerTimeEngine: any PrayerTimeCalculating
    let prayerTimeRepository: any PrayerTimeRepositoring
    let getPrayerSchedule: GetPrayerScheduleUseCase

    // MARK: Home

    /// How Home is arranged, and the three things that can be done to it.
    ///
    /// Built here rather than lazily like the view models because it reads nothing onboarding
    /// seeds — the customization screen is the only thing that ever writes this key, and it
    /// cannot have run before launch.
    /// Which prayers were prayed, by day. Read and written by Home's tracker row and by the day
    /// sheet, which are two views of one record.
    let prayerTrackerRepository: any PrayerTrackerRepositoring
    let prayerTracker: PrayerTrackerUseCase

    let homeLayoutRepository: any HomeLayoutRepositoring
    let getHomeLayout: GetHomeLayoutUseCase
    let updateHomeLayout: UpdateHomeLayoutUseCase
    let resetHomeLayout: ResetHomeLayoutUseCase

    // MARK: Qibla

    /// Built on the same engine as the prayer times above — one implementation of the Qibla
    /// formula in the app, not two.
    let getQiblaInfo: any GetQiblaInfoUseCase

    // MARK: Corpus

    /// The bundled, read-only reference content. Separate from `persistence` above, which is
    /// SwiftData and holds only what the user changes.
    ///
    /// Constructed here and handed to whichever repositories read it, so the file is opened once
    /// however many features come to depend on it — the adhkar, the tasbih and the 99 Names.
    /// Opening is deferred to the first read, so this line touches no disk.
    let corpus: any CorpusDatabaseProviding

    /// The Quran, which is a second file rather than more tables in the first.
    ///
    /// Its text is an order of magnitude larger than everything in `corpus` put together, and it
    /// has a different upstream and a different licence — so it is versioned, rebuilt and
    /// attributed on its own. `CorpusDatabase` is constructed with a resource name and knows
    /// nothing about what is inside it, which is what makes a second one free.
    let quranCorpus: any CorpusDatabaseProviding

    /// The commentaries, which are a third file for the third time the same argument holds: a
    /// different upstream, a different licence — public domain by age rather than by permission —
    /// and a size that grows with every edition added rather than staying put.
    let tafsirCorpus: any CorpusDatabaseProviding

    // MARK: Quran

    let quranRepository: any QuranRepositoring
    let getQuran: GetQuranUseCase

    let tafsirRepository: any TafsirRepositoring
    let getTafsir: GetTafsirUseCase

    /// The reader's own marks — bookmarks and where they left off. The other half of the Quran's
    /// storage split: `quranCorpus` above is read-only and bundled, this writes to the same
    /// SwiftData container the tasbih counts do.
    let quranProgressRepository: any QuranProgressRepositoring
    let quranProgress: QuranProgressUseCase

    /// How the reader has asked the page to look. Built here rather than lazily like the view
    /// models because it reads nothing onboarding seeds — the panel is the only thing that ever
    /// writes these three keys, and it cannot have run before launch.
    let readerSettings: ReaderSettings

    // MARK: Adhkar

    let adhkarRepository: any AdhkarRepositoring
    let getAdhkar: GetAdhkarUseCase

    // MARK: Tasbih

    /// The first feature assembled from both stores: phrases out of the read-only corpus,
    /// counts into SwiftData.
    let tasbihCatalog: any TasbihCatalogProviding
    let tasbihProgress: any TasbihProgressRepositoring
    let tasbihUseCase: TasbihUseCase

    // MARK: The 99 names

    let namesRepository: any NamesRepositoring
    let getNames: GetNamesUseCase

    // MARK: Onboarding

    let onboardingRepository: any OnboardingRepositoring
    let onboardingViewModel: OnboardingViewModel
    private(set) var onboardingCoordinator: OnboardingCoordinator!

    // MARK: Routing

    let router: AppRouter
    let homeCoordinator = HomeCoordinator()
    let qiblaCoordinator = QiblaCoordinator()
    let quranCoordinator = QuranCoordinator()
    let adhkarCoordinator = AdhkarCoordinator()
    let tasbihCoordinator = TasbihCoordinator()
    let namesCoordinator = NamesCoordinator()
    let settingsCoordinator = SettingsCoordinator()

    /// Where prayer times are computed for when onboarding captured nothing — a user who
    /// skipped the location screen entirely. Also the seed `HomeViewModel` shows for its first
    /// frame, before `locationService` has produced a live fix.
    private let fallbackCoordinates: Coordinates

    init(
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        numberFormatting: any NumberFormattingService = LocaleNumberFormattingService(),
        timeFormatting: any TimeFormattingService = LocaleTimeFormattingService(),
        persistence: PersistenceController = .makeDefault(),
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        locationService: (any LocationService)? = nil,
        headingProvider: (any HeadingProviding)? = nil,
        placeNameResolver: (any PlaceNameResolving)? = nil,
        clock: any ClockService = SystemClockService(),
        notificationService: (any NotificationService)? = nil,
        tipsService: any TipsServicing = TipsService(),
        hijriDates: any HijriDateServicing = HijriDateService(),
        corpus: any CorpusDatabaseProviding = CorpusDatabase(name: "corpus"),
        quranCorpus: any CorpusDatabaseProviding = CorpusDatabase(name: "quran"),
        tafsirCorpus: any CorpusDatabaseProviding = CorpusDatabase(name: "tafsir"),
        fallbackCoordinates: Coordinates = .makkah,
        // `false` in tests. `BGTaskScheduler.shared.register(_:)` (iOS only — a no-op read
        // elsewhere) is a real call into the system's background-task service — unlike
        // `locationService` or `notificationService`, there is no protocol here to hand a fake
        // to, so this is the escape hatch instead. Constructing a real `AppContainer()` in a
        // test (`AppRoutingTests` does, for its routing-through-the-container coverage) with
        // this left `true` registers for real from inside the test host process, which is a
        // different bundle than the app ships as — that mismatch is what surfaced as flaky,
        // unrelated-looking test failures and simulator instability across an entire run, not
        // a failure of this call itself. Unconditional (not `#if os(iOS)`) only because Swift
        // does not allow a single parameter in a list to be conditionally compiled cleanly.
        registersBackgroundRefresh: Bool = true
    ) {
        self.tipsService = tipsService
        self.hijriDates = hijriDates
        self.settingsStore = settingsStore
        self.numberFormatting = numberFormatting
        self.timeFormatting = timeFormatting
        self.persistence = persistence
        self.httpClient = httpClient
        self.fallbackCoordinates = fallbackCoordinates
        // Built here rather than defaulted in the signature: constructing a
        // `CLLocationManager` has real side effects, and a default argument would run it even
        // for a caller supplying its own.
        self.locationService = locationService ?? CoreLocationService()
        self.headingProvider = headingProvider ?? CoreLocationHeadingProvider()
        // Same reason as the two above: constructing a `CLGeocoder` in a default argument would
        // run it even for a caller supplying its own.
        self.placeNameResolver = placeNameResolver ?? CoreLocationPlaceNameResolver()
        self.clock = clock
        self.reminderPreferences = ReminderPreferences(settingsStore: settingsStore)

        self.themeManager = ThemeManager(settingsStore: settingsStore)
        self.localizationManager = LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: numberFormatting,
            timeFormatting: timeFormatting
        )
        self.bookmarkRepository = SwiftDataBookmarkRepository(
            modelContainer: persistence.container
        )

        let recentActivityRepository = RecentActivityRepository(
            modelContainer: persistence.container
        )
        let recentActivity = RecentActivityUseCase(repository: recentActivityRepository)
        self.recentActivityRepository = recentActivityRepository
        self.recentActivity = recentActivity
        self.activityRecorder = ActivityRecorder(useCase: recentActivity)

        // Engine → repository → use case. Each link depends on the protocol above it, so any
        // one of them can be swapped in a test without the others noticing.
        let engine = PrayerTimeEngine()
        let prayerTimeRepository = PrayerTimeRepository(engine: engine)
        self.prayerTimeEngine = engine
        self.prayerTimeRepository = prayerTimeRepository
        self.getPrayerSchedule = GetPrayerScheduleUseCase(repository: prayerTimeRepository)
        self.getQiblaInfo = GreatCircleQiblaInfoUseCase(engine: engine)

        // Built here rather than up with the other services because it needs two of them: the
        // repository the times come from, and the localization manager the words come from.
        // Everything it reads *late* — position, method, toggles — it reads through
        // `AppReminderInputs` at refresh time instead of capturing now.
        self.notificationService = notificationService ?? UserNotificationService(
            center: UserNotificationCenterClient(),
            planner: PrayerReminderPlanner(repository: prayerTimeRepository),
            content: LocalizedReminderContent(l10n: self.localizationManager),
            inputs: AppReminderInputs(
                location: self.locationService,
                settingsStore: settingsStore
            )
        )

        #if os(iOS)
        self.backgroundRefreshScheduler = BackgroundRefreshScheduler(
            notificationService: self.notificationService
        )
        #endif

        // Same three-link shape as the prayer times above, over a database instead of a
        // calculation: corpus → repository → use case.
        let adhkarRepository = AdhkarRepository(database: corpus)
        self.corpus = corpus
        self.adhkarRepository = adhkarRepository
        self.getAdhkar = GetAdhkarUseCase(repository: adhkarRepository)

        // Both halves of the storage split, met in one use case: the same corpus the adhkar read
        // from, and the same `ModelContainer` the bookmarks write to.
        let tasbihCatalog = TasbihCatalogRepository(database: corpus)
        let tasbihProgress = TasbihProgressRepository(modelContainer: persistence.container)
        self.tasbihCatalog = tasbihCatalog
        self.tasbihProgress = tasbihProgress
        self.tasbihUseCase = TasbihUseCase(catalog: tasbihCatalog, progress: tasbihProgress)

        // The third reader of the same corpus, and the simplest: read-only all the way down.
        let namesRepository = NamesRepository(database: corpus)
        self.namesRepository = namesRepository
        self.getNames = GetNamesUseCase(repository: namesRepository)

        // The same three links again, over the other file. Nothing but this line and the
        // property above knows there are two databases.
        let quranRepository = QuranRepository(database: quranCorpus)
        self.quranCorpus = quranCorpus
        self.quranRepository = quranRepository
        self.getQuran = GetQuranUseCase(repository: quranRepository)
        self.readerSettings = ReaderSettings(settingsStore: settingsStore)

        // And a third time, over the commentaries.
        let tafsirRepository = TafsirRepository(database: tafsirCorpus)
        self.tafsirCorpus = tafsirCorpus
        self.tafsirRepository = tafsirRepository
        self.getTafsir = GetTafsirUseCase(repository: tafsirRepository)

        let quranProgressRepository = QuranProgressRepository(
            modelContainer: persistence.container
        )
        self.quranProgressRepository = quranProgressRepository
        self.quranProgress = QuranProgressUseCase(repository: quranProgressRepository)

        let prayerTrackerRepository = PrayerTrackerRepository(
            modelContainer: persistence.container
        )
        self.prayerTrackerRepository = prayerTrackerRepository
        self.prayerTracker = PrayerTrackerUseCase(repository: prayerTrackerRepository)

        let homeLayoutRepository = HomeLayoutRepository(settingsStore: settingsStore)
        self.homeLayoutRepository = homeLayoutRepository
        self.getHomeLayout = GetHomeLayoutUseCase(repository: homeLayoutRepository)
        self.updateHomeLayout = UpdateHomeLayoutUseCase(repository: homeLayoutRepository)
        self.resetHomeLayout = ResetHomeLayoutUseCase(repository: homeLayoutRepository)

        let onboardingRepository = OnboardingRepository(settingsStore: settingsStore)
        self.onboardingRepository = onboardingRepository

        // The launch decision, made once from the persisted flag.
        let router = AppRouter(hasCompletedOnboarding: onboardingRepository.hasCompletedOnboarding)
        self.router = router

        self.onboardingViewModel = OnboardingViewModel(
            locationService: self.locationService,
            notificationService: self.notificationService,
            completeOnboarding: CompleteOnboardingUseCase(repository: onboardingRepository)
        )

        // Two-phase because the coordinator's completion handler needs the router, and the
        // router's initial value needs the repository. Confined to this one line.
        self.onboardingCoordinator = OnboardingCoordinator(
            viewModel: onboardingViewModel,
            onFinished: { [router] in router.onboardingFinished() }
        )

        // Before any view exists: a `TipView` or `.popoverTip(_:)` built against an
        // unconfigured datastore never displays and logs on every redraw.
        tipsService.configure()

        #if os(iOS)
        // Same requirement, stricter: `BGTaskScheduler` fatals if `register()` runs any later
        // than the app finishing launch, so this cannot wait for `RootView` to appear either.
        // Skipped in tests — see `registersBackgroundRefresh`'s own documentation for why.
        if registersBackgroundRefresh {
            backgroundRefreshScheduler.register()
        }
        #endif

        // Networking is optional, but knowing whether it is available is cheap and lets the
        // UI gate online-only actions from launch.
        reachability.start()
    }

    // MARK: Prayer calculation

    private var cachedCalculationSettings: CalculationSettings?

    /// The calculation choices, shared by Home and Settings.
    ///
    /// Lazy for the same reason Home's view model is: it has to read what onboarding seeded, which
    /// has not been written yet when `init` runs. Cached because *sharing the instance is the
    /// point* — a second one would leave Settings editing a copy Home never sees.
    func calculationSettings() -> CalculationSettings {
        if let cachedCalculationSettings {
            return cachedCalculationSettings
        }

        let settings = CalculationSettings(
            config: onboardingRepository.seededConfig ?? .default,
            settingsStore: settingsStore
        )
        cachedCalculationSettings = settings
        return settings
    }

    // MARK: Settings

    /// Settings' seven screens, each with a view model of its own.
    ///
    /// Cached, and for two different reasons depending on the screen. Most of them hold no
    /// preference at all — they forward to the manager that owns it — but they do hold *screen*
    /// state: a confirmation that is up, a status that has been read. Rebuilding one on each push
    /// would discard that, which is how a reset confirmation ends up dismissing itself.
    ///
    /// Built lazily, together, because two of them need what onboarding seeded and none of them
    /// is needed before Settings is opened.
    private var cachedSettingsScreens: SettingsScreenModels?

    private func settingsScreens() -> SettingsScreenModels {
        if let cachedSettingsScreens {
            return cachedSettingsScreens
        }

        let screens = SettingsScreenModels(
            homeCustomization: homeCustomizationViewModel(),
            appearance: AppearanceSettingsViewModel(theme: themeManager),
            languageAndFormat: LanguageFormatSettingsViewModel(localization: localizationManager),
            prayerCalculation: PrayerCalculationSettingsViewModel(
                calculation: calculationSettings()
            ),
            reminders: RemindersSettingsViewModel(
                reminders: reminderPreferences,
                notifications: notificationService
            ),
            tips: TipsSettingsViewModel(resetTips: ResetTipsUseCase(tips: tipsService)),
            about: AboutViewModel()
        )
        cachedSettingsScreens = screens
        return screens
    }

    /// What `SettingsView` routes to. See `SettingsScreens` for why the view names a protocol
    /// rather than taking the container.
    var settings: any SettingsScreens { settingsScreens() }

    // MARK: Home

    private var cachedHomeViewModel: HomeViewModel?

    /// Home's view model, built on first use and kept.
    ///
    /// Lazy on purpose. Home is only ever reached *after* the routing decision, so building
    /// it here — rather than in `init` — is what lets it read the values onboarding has just
    /// seeded instead of the defaults that were in place at launch.
    func homeViewModel() -> HomeViewModel {
        if let cachedHomeViewModel {
            return cachedHomeViewModel
        }

        let viewModel = HomeViewModel(
            useCase: getPrayerSchedule,
            getLayout: getHomeLayout,
            coordinates: onboardingRepository.seededCoordinates ?? fallbackCoordinates,
            locationService: locationService,
            placeNames: placeNameResolver,
            // Consulted before the card asks for a city name, so a device with the radio off
            // never makes a request that can only fail.
            reachability: reachability,
            hijriDates: hijriDates,
            // The same object Settings edits, not a snapshot of it — which is what lets a method
            // changed in Settings redraw today's times.
            calculation: calculationSettings(),
            // Home reaching into the Quran's use cases, on purpose: the "continue reading"
            // section is *about* the Quran, and a second way to ask where the reader stopped
            // would be a second answer waiting to disagree with the first.
            quranProgress: quranProgress,
            quran: getQuran,
            // Two more of somebody else's use cases, for the same reason: the chips name a
            // chapter and a dhikr, and resolving those names anywhere but through the feature
            // that owns them would be a second copy of the corpus's vocabulary.
            tasbih: tasbihUseCase,
            recentActivity: recentActivity,
            tracker: prayerTracker,
            clock: clock
        )
        cachedHomeViewModel = viewModel
        return viewModel
    }

    private var cachedPrayerTimesSheetViewModel: PrayerTimesSheetViewModel?

    /// The day sheet's view model, built on first use and kept.
    ///
    /// Kept so the date the user stepped to is still there if they close the sheet and reopen it
    /// in the same sitting — and reads its coordinates through Home's rather than capturing them,
    /// so a live fix that lands while Home is open reaches it too.
    func prayerTimesSheetViewModel() -> PrayerTimesSheetViewModel {
        if let cachedPrayerTimesSheetViewModel {
            return cachedPrayerTimesSheetViewModel
        }

        let home = homeViewModel()
        let viewModel = PrayerTimesSheetViewModel(
            useCase: getPrayerSchedule,
            tracker: prayerTracker,
            calculation: calculationSettings(),
            hijriDates: hijriDates,
            coordinates: { home.coordinates },
            clock: clock
        )
        cachedPrayerTimesSheetViewModel = viewModel
        return viewModel
    }

    private var cachedHomeCustomizationViewModel: HomeCustomizationViewModel?

    /// The arranging screen's view model, built on first use and kept.
    ///
    /// One instance for both doors into it — Home's shortcuts header and Settings — so a change
    /// made through one is on screen when the other is opened. It calls back into Home's view
    /// model after each write, which is what makes the screen behind follow along rather than
    /// waiting to be re-entered.
    func homeCustomizationViewModel() -> HomeCustomizationViewModel {
        if let cachedHomeCustomizationViewModel {
            return cachedHomeCustomizationViewModel
        }

        let home = homeViewModel()
        let viewModel = HomeCustomizationViewModel(
            getLayout: getHomeLayout,
            updateLayout: updateHomeLayout,
            resetLayout: resetHomeLayout,
            onChange: { home.reloadLayout() }
        )
        cachedHomeCustomizationViewModel = viewModel
        return viewModel
    }

    // MARK: Qibla

    private var cachedQiblaViewModel: QiblaViewModel?

    /// Qibla's view model, built on first use and kept.
    ///
    /// Lazy for the same reason as Home's, and seeded from the same place — but with **no**
    /// `fallbackCoordinates`. Prayer times computed for Makkah are at least a defensible
    /// placeholder; a Qibla arrow computed for a position the user is not at points confidently
    /// in the wrong direction, which is worse than admitting there is nothing to point with.
    func qiblaViewModel() -> QiblaViewModel {
        if let cachedQiblaViewModel {
            return cachedQiblaViewModel
        }

        let viewModel = QiblaViewModel(
            getQiblaInfo: getQiblaInfo,
            locationService: locationService,
            headingProvider: headingProvider,
            coordinates: onboardingRepository.seededCoordinates
        )
        cachedQiblaViewModel = viewModel
        return viewModel
    }

    // MARK: Quran

    private var cachedQuranViewModel: QuranViewModel?

    /// The Quran's view model, built on first use and kept.
    ///
    /// Kept rather than rebuilt because the chosen segment and the loaded lists live on it: a
    /// reader who was looking at the parts, opened one, and came back should find the parts
    /// still selected and no second read of the corpus behind it.
    func quranViewModel() -> QuranViewModel {
        if let cachedQuranViewModel {
            return cachedQuranViewModel
        }

        let viewModel = QuranViewModel(
            useCase: getQuran,
            progress: quranProgress,
            activity: activityRecorder
        )
        cachedQuranViewModel = viewModel
        return viewModel
    }

    private var cachedTafsirViewModel: TafsirViewModel?

    /// The tafsir sheet's view model, built on first use and kept.
    ///
    /// One for the app rather than one per verse: the sheet shows a single verse at a time, and
    /// `TafsirSheet`'s `.task(id:)` reloads it when the reader taps another. Rebuilding it per
    /// row would put a view model inside a `LazyVStack` child, which the scroll throws away.
    func tafsirViewModel() -> TafsirViewModel {
        if let cachedTafsirViewModel {
            return cachedTafsirViewModel
        }

        let viewModel = TafsirViewModel(useCase: getTafsir)
        cachedTafsirViewModel = viewModel
        return viewModel
    }

    // MARK: Adhkar

    private var cachedAdhkarViewModel: AdhkarViewModel?

    /// Adhkar's view model, built on first use and kept.
    ///
    /// Kept rather than rebuilt because the repeat counts live on it: a reader who leaves the
    /// morning adhkar to check the Qibla and comes back should find their place, and rebuilding
    /// on every push would silently reset them.
    func adhkarViewModel() -> AdhkarViewModel {
        if let cachedAdhkarViewModel {
            return cachedAdhkarViewModel
        }

        let viewModel = AdhkarViewModel(useCase: getAdhkar, activity: activityRecorder)
        cachedAdhkarViewModel = viewModel
        return viewModel
    }

    // MARK: Tasbih

    private var cachedTasbihViewModel: TasbihViewModel?

    /// Tasbih's view model, built on first use and kept.
    ///
    /// Kept for a stronger reason than the other two: it holds counted taps that have not reached
    /// the store yet. Rebuilding it on each push would discard whatever was counted since the
    /// last lap — the one thing this feature must not lose.
    func tasbihViewModel() -> TasbihViewModel {
        if let cachedTasbihViewModel {
            return cachedTasbihViewModel
        }

        let viewModel = TasbihViewModel(useCase: tasbihUseCase, activity: activityRecorder)
        cachedTasbihViewModel = viewModel
        return viewModel
    }

    // MARK: The 99 names

    private var cachedNamesViewModel: NamesViewModel?

    /// The names' view model, built on first use and kept.
    ///
    /// Kept for the mildest of the three reasons: nothing here is at risk of being lost, but
    /// holding it means returning to the grid keeps the search text and skips a re-read of
    /// ninety-nine rows.
    func namesViewModel() -> NamesViewModel {
        if let cachedNamesViewModel {
            return cachedNamesViewModel
        }

        let viewModel = NamesViewModel(useCase: getNames)
        cachedNamesViewModel = viewModel
        return viewModel
    }
}
