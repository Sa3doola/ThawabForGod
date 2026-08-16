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
    let notificationService: any NotificationService
    let tipsService: any TipsServicing
    let hijriDates: any HijriDateServicing
    let reachability = ReachabilityMonitor()

    // MARK: Prayer times

    let prayerTimeEngine: any PrayerTimeCalculating
    let prayerTimeRepository: any PrayerTimeRepositoring
    let getPrayerSchedule: GetPrayerScheduleUseCase

    // MARK: Onboarding

    let onboardingRepository: any OnboardingRepositoring
    let onboardingViewModel: OnboardingViewModel
    private(set) var onboardingCoordinator: OnboardingCoordinator!

    // MARK: Routing

    let router: AppRouter
    let homeCoordinator = HomeCoordinator()

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
        notificationService: (any NotificationService)? = nil,
        tipsService: any TipsServicing = TipsService(),
        hijriDates: any HijriDateServicing = HijriDateService(),
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
}
