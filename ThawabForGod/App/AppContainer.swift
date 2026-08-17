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
    let notificationService: any NotificationService
    let tipsService: any TipsServicing
    let hijriDates: any HijriDateServicing
    let reachability = ReachabilityMonitor()

    // MARK: Prayer times

    let prayerTimeEngine: any PrayerTimeCalculating
    let prayerTimeRepository: any PrayerTimeRepositoring
    let getPrayerSchedule: GetPrayerScheduleUseCase

    // MARK: Qibla

    /// Built on the same engine as the prayer times above — one implementation of the Qibla
    /// formula in the app, not two.
    let getQiblaInfo: any GetQiblaInfoUseCase

    // MARK: Corpus

    /// The bundled, read-only reference content. Separate from `persistence` above, which is
    /// SwiftData and holds only what the user changes.
    ///
    /// Constructed here and handed to whichever repositories read it, so the file is opened once
    /// however many features come to depend on it — adhkar today; tasbih, the 99 Names and the
    /// Quran later. Opening is deferred to the first read, so this line touches no disk.
    let corpus: any CorpusDatabaseProviding

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
    let adhkarCoordinator = AdhkarCoordinator()
    let tasbihCoordinator = TasbihCoordinator()
    let namesCoordinator = NamesCoordinator()

    /// Where prayer times are computed for when onboarding captured nothing — a user who
    /// skipped the location screen entirely. Replaced by a live reading when the location
    /// slice wires `LocationService` into Home.
    private let fallbackCoordinates: Coordinates

    init(
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        numberFormatting: any NumberFormattingService = LocaleNumberFormattingService(),
        timeFormatting: any TimeFormattingService = LocaleTimeFormattingService(),
        persistence: PersistenceController = .makeDefault(),
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        locationService: (any LocationService)? = nil,
        headingProvider: (any HeadingProviding)? = nil,
        notificationService: (any NotificationService)? = nil,
        tipsService: any TipsServicing = TipsService(),
        hijriDates: any HijriDateServicing = HijriDateService(),
        corpus: any CorpusDatabaseProviding = CorpusDatabase(name: "corpus"),
        fallbackCoordinates: Coordinates = .makkah
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
        self.notificationService = notificationService ?? UserNotificationService()

        self.themeManager = ThemeManager(settingsStore: settingsStore)
        self.localizationManager = LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: numberFormatting,
            timeFormatting: timeFormatting
        )
        self.bookmarkRepository = SwiftDataBookmarkRepository(
            modelContainer: persistence.container
        )

        // Engine → repository → use case. Each link depends on the protocol above it, so any
        // one of them can be swapped in a test without the others noticing.
        let engine = PrayerTimeEngine()
        let prayerTimeRepository = PrayerTimeRepository(engine: engine)
        self.prayerTimeEngine = engine
        self.prayerTimeRepository = prayerTimeRepository
        self.getPrayerSchedule = GetPrayerScheduleUseCase(repository: prayerTimeRepository)
        self.getQiblaInfo = GreatCircleQiblaInfoUseCase(engine: engine)

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

        // Networking is optional, but knowing whether it is available is cheap and lets the
        // UI gate online-only actions from launch.
        reachability.start()
    }

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
            coordinates: onboardingRepository.seededCoordinates ?? fallbackCoordinates,
            hijriDates: hijriDates,
            config: onboardingRepository.seededConfig ?? .default
        )
        cachedHomeViewModel = viewModel
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

        let viewModel = AdhkarViewModel(useCase: getAdhkar)
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

        let viewModel = TasbihViewModel(useCase: tasbihUseCase)
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
