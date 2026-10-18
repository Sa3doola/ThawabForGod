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

    /// Told when anything the widgets are drawn from has changed. See `WidgetRefreshing`.
    let widgets: any WidgetRefreshing

    #if os(macOS)
    /// Whether Noor sits in the menu bar, and whether it keeps its Dock icon.
    let menuBarPreferences: MenuBarPreferences

    /// Registering the app as a login item. macOS's state, not this app's.
    let launchAtLogin: any LaunchAtLoginServicing

    /// The status item and its panel. Owned here rather than by `MacAppDelegate`, which AppKit
    /// constructs with no argument list to inject six collaborators through — see
    /// `MenuBarController`. Built after the two-phase init below, hence the implicit unwrap.
    private(set) var menuBar: MenuBarController!
    #endif

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

    /// The two Sahihs, a file of their own for the reason the Quran's is: a different upstream, a
    /// different licence, and at twenty-four megabytes larger than everything else together —
    /// only a reader who opens that tab ever pays to page any of it in.
    let hadithCorpus: any CorpusDatabaseProviding

    // MARK: Quran

    /// The Quran database the app reads: the full (QUL) build when it was bundled, the public
    /// (Tanzil) one otherwise (T4). What the screens may offer is `quranRepository.capabilities()`,
    /// read from the file — never inferred from which file this is.
    let quranDatabase: QuranDatabase
    let quranRepository: any QuranRepositoring
    /// Search over the same database, and over the translation packs.
    let quranSearch: any QuranSearchRepositoring

    /// The translation, tafsir and surah-info packs, found in the bundle by file prefix (T15).
    let quranPacks: any ContentPackStoring
    let quranTranslations: any TranslationRepositoring
    let quranTafsir: any TafsirRepositoring
    let quranSurahInfo: any SurahInfoRepositoring
    /// The translations separated mode draws under each ayah: one for the section, so a rebuilt
    /// list finds its surah already loaded.
    let quranSeparatedTranslations: SeparatedTranslationsModel

    /// The 604 page fonts, registered a window at a time around the page on screen (T1). One for
    /// the app, owned here rather than a global, because the registrations it tracks are the
    /// process's.
    let quranPageFonts: any FontPackStoring

    /// How the reader looks and is laid out (D4): one instance, read by the reader and written by
    /// its settings sheet. It learns what the database can draw from the reader, which has to ask
    /// the database anyway, rather than from a second query here at launch.
    let quranReaderSettings: QuranReaderSettings

    /// The reader's corpus, reading place and display-mode switch: one for the app, shared by the
    /// tab's root and the reader. Touches no disk until its first `load()`.
    let quranReaderViewModel: QuranReaderViewModel

    /// Whether surah info exists in this interface language, and the introduction being read. One
    /// for the section, over the reader's corpus.
    let quranSurahInfoViewModel: SurahInfoViewModel

    /// The ayah panel's packs, translations and tafsir: one for the section, so the packs load once
    /// and the picked tafsir survives the view tree being rebuilt.
    let quranAyahPanelViewModel: AyahPanelViewModel

    /// The Quran preferences form's model: one instance serves Settings → Quran and the reader's
    /// settings sheet, so both show the same selections.
    let quranSettingsViewModel: QuranSettingsViewModel

    /// What the app is built from, with the Quran's sources read from this build's database and
    /// packs. One for the app, used by Settings and by the reader's sheet.
    let aboutViewModel: AboutViewModel

    /// The Library's indexes, field and tab: one for the section, built before any view so a
    /// rebuilt view tree finds them as they were left.
    let quranLibraryViewModel: QuranLibraryViewModel

    /// Search's text, scope and results: one for the section, so they survive opening a result and
    /// the view tree being rebuilt.
    let quranSearchViewModel: QuranSearchViewModel

    /// Page measurements for the session, measured off the main actor and read synchronously by the
    /// pages (T13). One per app, where Mushaf had a `static let shared`.
    let quranPageMetrics = PageMetricsCache()

    /// The Quran faces that registered: the full set where the QUL fonts were installed, KFGQPC
    /// Hafs alone in a public clone.
    var quranFaces: QuranFaces { .launch }

    /// The reader's bookmarks, notes, highlights and reading position, in memory and mirrored to
    /// SwiftData. One for the app; loaded at the end of `init`.
    let quranUserData: QuranUserDataStore

    /// The bookmarks list's kind and sort: one for the section, so they survive the view tree being
    /// rebuilt. Session-only.
    let quranBookmarksViewModel: QuranBookmarksViewModel

    /// What a Mushaf page needs to draw, handed to the pager.
    var mushafRenderServices: MushafRenderServices {
        MushafRenderServices(pageFonts: quranPageFonts, metricsCache: quranPageMetrics)
    }

    // MARK: Hadith

    let hadithRepository: any HadithRepositoring
    let getHadith: GetHadithUseCase

    /// The reader's own marks in the hadith. The other half of this feature's storage split:
    /// `hadithCorpus` above is read-only and bundled, this writes to the same SwiftData container
    /// the tasbih counts do.
    let hadithProgressRepository: any HadithProgressRepositoring
    let hadithProgress: HadithProgressUseCase

    /// The review schedule. A third store-facing piece in this feature, beside the corpus and the
    /// bookmarks, because a schedule is a different kind of thing from a ribbon — and because the
    /// `Memorize` mode the plan wants across the adhkar and the divine names will want this shape
    /// rather than the bookmarks'.
    let hadithMemorizationRepository: any HadithMemorizationRepositoring
    let memorizeHadith: MemorizeHadithUseCase

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
    /// Built in `init`, not here: it applies a target to the reader before pushing it, so it is
    /// constructed over `quranReaderViewModel`.
    let quranCoordinator: QuranCoordinator
    let hadithCoordinator = HadithCoordinator()
    let adhkarCoordinator = AdhkarCoordinator()
    let tasbihCoordinator = TasbihCoordinator()
    let namesCoordinator = NamesCoordinator()
    let settingsCoordinator = SettingsCoordinator()

    /// Where a link from outside the app waits until `RootView` can act on it — a quick action,
    /// a Dock menu item, a widget tap. See `DeepLinkInbox` for why the wait is necessary.
    let deepLinks = DeepLinkInbox()

    /// Where prayer times are computed for when onboarding captured nothing — a user who
    /// skipped the location screen entirely. Also the seed `HomeViewModel` shows for its first
    /// frame, before `locationService` has produced a live fix.
    private let fallbackCoordinates: Coordinates

    init(
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(defaults: SharedDefaults.store),
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
        widgets: any WidgetRefreshing = WidgetCenterRefresher(),
        hijriDates: any HijriDateServicing = HijriDateService(),
        corpus: any CorpusDatabaseProviding = CorpusDatabase(name: "corpus"),
        hadithCorpus: any CorpusDatabaseProviding = CorpusDatabase(name: "hadith"),
        quranDatabase: QuranDatabase = .bundled(),
        quranPacks: any ContentPackStoring = ContentPackStore(),
        fallbackCoordinates: Coordinates = .makkah,
        // `false` in tests that only need a container. When `true` (iOS only — a no-op read
        // elsewhere), this container publishes its `BackgroundRefreshScheduler` as the one the
        // background launch handler runs. A container built by a test, with a mock notification
        // service, must never become the target of the host app's handler, so this is the escape
        // hatch. Registering the handler is no longer the container's job: the app delegate does
        // that at launch, and this flag only decides which scheduler it finds. Unconditional (not
        // `#if os(iOS)`) only because Swift does not allow a single parameter in a list to be
        // conditionally compiled cleanly.
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
        self.widgets = widgets
        #if os(macOS)
        self.menuBarPreferences = MenuBarPreferences(settingsStore: settingsStore)
        self.launchAtLogin = SMAppServiceLaunchAtLogin()
        #endif
        self.locationService = locationService ?? CoreLocationService(settingsStore: settingsStore)
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
            ),
            artwork: ReminderArtwork(settingsStore: settingsStore)
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

        // The Quran: one database, chosen by what is bundled, read by the repository and by search;
        // the packs found beside it and joined to it through the ayah index rather than `ATTACH`.
        #if DEBUG
        // `-quranData public` reads the Tanzil database even where the full one is bundled, so the
        // capability gating can be exercised without a public clone. The database only: packs and
        // faces stay what the bundle has.
        let quranDatabase = QuranLaunchOptions.current.usesPublicData
            ? QuranDatabase(
                resourceName: QuranDatabase.publicResourceName,
                corpus: CorpusDatabase(name: QuranDatabase.publicResourceName)
            )
            : quranDatabase
        #endif
        let quranAyahIndex = QuranAyahIndex(database: quranDatabase.corpus)
        self.quranDatabase = quranDatabase
        let quranRepository = QuranRepository(database: quranDatabase.corpus)
        self.quranRepository = quranRepository
        self.quranPacks = quranPacks
        self.quranSearch = QuranSearchRepository(quran: quranDatabase.corpus, store: quranPacks, index: quranAyahIndex)
        let quranTranslations = TranslationRepository(store: quranPacks, index: quranAyahIndex)
        self.quranTranslations = quranTranslations
        self.quranSeparatedTranslations = SeparatedTranslationsModel(repository: quranTranslations)
        self.quranTafsir = TafsirRepository(store: quranPacks, index: quranAyahIndex)
        let quranSurahInfo = SurahInfoRepository(store: quranPacks)
        self.quranSurahInfo = quranSurahInfo
        self.quranPageFonts = FontPackStore()
        #if DEBUG
        // A scripted launch's reader choices are written before the settings object, the view models
        // or any view exist, through the settings type itself so the key mapping stays in one place.
        // The throwaway object is told the build can do everything, so `-quranMode mushaf` is stored
        // like a reader's choice; the real object then reads it and judges it against what the
        // database turns out to carry.
        if QuranLaunchOptions.current.isQuranLaunch {
            QuranLaunchOptions.current.apply(to: QuranReaderSettings(settingsStore: settingsStore, capabilities: [.text, .mushafPages]))
        }
        #endif
        let quranReaderSettings = QuranReaderSettings(settingsStore: settingsStore)
        self.quranReaderSettings = quranReaderSettings
        let quranReaderViewModel = QuranReaderViewModel(
            repository: quranRepository,
            settings: quranReaderSettings
        )
        self.quranReaderViewModel = quranReaderViewModel
        let quranSurahInfoViewModel = SurahInfoViewModel(repository: quranSurahInfo, reader: quranReaderViewModel)
        self.quranSurahInfoViewModel = quranSurahInfoViewModel
        self.quranAyahPanelViewModel = AyahPanelViewModel(
            translations: quranTranslations,
            tafsir: quranTafsir,
            settings: quranReaderSettings
        )
        self.quranSettingsViewModel = QuranSettingsViewModel(
            settings: quranReaderSettings,
            reader: quranReaderViewModel,
            translations: quranTranslations,
            tafsir: quranTafsir
        )
        self.aboutViewModel = AboutViewModel(quran: quranRepository, packs: quranPacks)
        self.quranLibraryViewModel = QuranLibraryViewModel(reader: quranReaderViewModel, surahInfo: quranSurahInfoViewModel)
        let quranSearchViewModel = QuranSearchViewModel(
            search: self.quranSearch,
            translations: quranTranslations,
            reader: quranReaderViewModel
        )
        self.quranSearchViewModel = quranSearchViewModel
        self.quranCoordinator = QuranCoordinator(reader: quranReaderViewModel, search: quranSearchViewModel)

        // The same three links again, over the two Sahihs. Another file and the same
        // `CorpusDatabase`, which is the point of that type taking a resource name and knowing
        // nothing else about what it opens.
        let hadithRepository = HadithRepository(database: hadithCorpus)
        self.hadithCorpus = hadithCorpus
        self.hadithRepository = hadithRepository
        self.getHadith = GetHadithUseCase(repository: hadithRepository)

        let hadithProgressRepository = HadithProgressRepository(
            modelContainer: persistence.container
        )
        self.hadithProgressRepository = hadithProgressRepository
        self.hadithProgress = HadithProgressUseCase(
            progress: hadithProgressRepository,
            corpus: hadithRepository
        )

        let hadithMemorizationRepository = HadithMemorizationRepository(
            modelContainer: persistence.container
        )
        self.hadithMemorizationRepository = hadithMemorizationRepository
        self.memorizeHadith = MemorizeHadithUseCase(
            memorization: hadithMemorizationRepository,
            corpus: hadithRepository
        )

        // One actor behind both protocols; the store is the only thing that holds it.
        let quranUserDataRepository = QuranUserDataRepository(modelContainer: persistence.container)
        self.quranUserData = QuranUserDataStore(
            repository: quranUserDataRepository,
            positions: quranUserDataRepository
        )
        self.quranBookmarksViewModel = QuranBookmarksViewModel(
            userData: quranUserData,
            reader: quranReaderViewModel
        )

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
        #if DEBUG
        // A scripted launch into the Quran reader (golden pages, UI tests, performance runs) starts
        // on the Quran tab and past onboarding, for this launch only: nothing is written, so the
        // flag is still unset next time.
        let quranLaunch = QuranLaunchOptions.current.isQuranLaunch
        let router = AppRouter(hasCompletedOnboarding: onboardingRepository.hasCompletedOnboarding || quranLaunch)
        if quranLaunch { router.selectedTab = .quran }
        #else
        let router = AppRouter(hasCompletedOnboarding: onboardingRepository.hasCompletedOnboarding)
        #endif
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
        // Publishes only; it does not register. This initialiser can run as late as the first
        // scene's connection (observed), after the app has finished launching, and
        // `BGTaskScheduler` fatals on a launch handler registered that late. The handler is
        // registered by `AppDelegate.application(_:didFinishLaunchingWithOptions:)` and finds
        // this scheduler through `current` when a task fires.
        // Skipped by most tests — see `registersBackgroundRefresh`'s own documentation for why.
        if registersBackgroundRefresh {
            BackgroundRefreshScheduler.makeCurrent(backgroundRefreshScheduler)
        }
        #endif

        // Networking is optional, but knowing whether it is available is cheap and lets the
        // UI gate online-only actions from launch.
        reachability.start()

        // The scene delegate and the Dock menu are constructed by UIKit and AppKit with no
        // argument list to inject anything through, so the composition root publishes the inbox
        // for them rather than being reached into. It is still the container that owns it.
        DeepLinkInbox.makeCurrent(deepLinks)

        #if os(macOS)
        // After everything else, because it captures `self` to route a tap out of the panel —
        // the same two-phase shape `onboardingCoordinator` uses, and for the same reason.
        menuBar = MenuBarController(
            viewModel: MenuBarPanelViewModel(
                timeline: NextPrayerTimeline(
                    schedule: getPrayerSchedule,
                    settingsStore: settingsStore
                ),
                l10n: localizationManager,
                tracker: prayerTracker
            ),
            preferences: menuBarPreferences,
            themeManager: themeManager,
            l10n: localizationManager,
            open: { [weak self] link in self?.open(link) }
        )
        menuBar.apply()
        #endif

        #if DEBUG
        // A scripted launch into the reader starts with the stack already holding it. Last among the
        // stored properties because it uses `self`; the place itself is applied by
        // `QuranLaunchHooks`, in order, once the reader has loaded.
        if QuranLaunchOptions.current.readerTarget != nil { quranCoordinator.openReader() }
        // A request, judged by the view model's own getter once the index exists.
        if let tab = QuranLaunchOptions.current.libraryTab { quranLibraryViewModel.tab = tab }
        #endif

        // An install that predates the App Group has its preferences in the process's own
        // defaults, where no extension can see them. Once, on the first launch of a build that
        // has the group, they are copied across — see `SettingsGroupMigration` for why it copies
        // only what is already there. A no-op on every launch after, and a no-op in tests, whose
        // `settingsStore` is injected and never touches `UserDefaults` at all.
        SettingsGroupMigration.run()

        // Last, so every collaborator exists; the store applies edits made before the load lands.
        quranUserData.load()
        #if DEBUG
        quranUserData.applyDebugLaunchOptions(QuranLaunchOptions.current)
        #endif
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

        // Named first, because `#if` is not allowed inside an argument list and the alternative
        // is two near-identical calls to the same initializer.
        let homeCustomization = homeCustomizationViewModel()
        #if os(iOS)
        let appearance = AppearanceSettingsViewModel(
            theme: themeManager,
            appIcons: UIApplicationIconSwitcher()
        )
        #else
        // The Mac has no alternate icons, so the Appearance screen draws no section for them.
        let appearance = AppearanceSettingsViewModel(theme: themeManager, appIcons: nil)
        #endif
        let languageAndFormat = LanguageFormatSettingsViewModel(localization: localizationManager)
        let prayerCalculation = PrayerCalculationSettingsViewModel(calculation: calculationSettings())
        let reminders = RemindersSettingsViewModel(
            reminders: reminderPreferences,
            notifications: notificationService
        )
        let tips = TipsSettingsViewModel(resetTips: ResetTipsUseCase(tips: tipsService))

        #if os(macOS)
        let screens = SettingsScreenModels(
            homeCustomization: homeCustomization,
            appearance: appearance,
            languageAndFormat: languageAndFormat,
            prayerCalculation: prayerCalculation,
            reminders: reminders,
            tips: tips,
            about: aboutViewModel,
            quranSettings: quranSettingsViewModel,
            macIntegration: MacSettingsViewModel(
                preferences: menuBarPreferences,
                loginItem: launchAtLogin,
                // The screen says a preference changed; the controller is what acts on it.
                onMenuBarChanged: { [weak self] in self?.menuBar.apply() }
            )
        )
        #else
        let screens = SettingsScreenModels(
            homeCustomization: homeCustomization,
            appearance: appearance,
            languageAndFormat: languageAndFormat,
            prayerCalculation: prayerCalculation,
            reminders: reminders,
            tips: tips,
            about: aboutViewModel,
            quranSettings: quranSettingsViewModel
        )
        #endif
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
            // Somebody else's use cases, on purpose: the chips name an adhkar chapter and a
            // dhikr, and resolving those names anywhere but through the feature that owns them
            // would be a second copy of the corpus's vocabulary. The Quran's "continue reading"
            // and chapter names come back with the ported reader's user data (M6).
            tasbih: tasbihUseCase,
            adhkar: getAdhkar,
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
            reminders: reminderPreferences,
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

    // MARK: Hadith

    private var cachedHadithViewModel: HadithViewModel?

    /// The hadith view model, built on first use and kept.
    ///
    /// Kept rather than rebuilt because it holds what the reader left on screen — the selected
    /// collection, and the narrations of the open kitab, which for Muslim's Book of Faith is 439 of them. Rebuilding
    /// on every push would re-read all of that off disk to show the reader what they were
    /// already looking at.
    func hadithViewModel() -> HadithViewModel {
        if let cachedHadithViewModel {
            return cachedHadithViewModel
        }

        let viewModel = HadithViewModel(
            useCase: getHadith,
            progress: hadithProgress,
            memorize: memorizeHadith,
            clock: clock
        )
        cachedHadithViewModel = viewModel
        return viewModel
    }

    private var cachedHadithMemorizeViewModel: HadithMemorizeViewModel?

    /// The review session's view model, built on first use and kept.
    ///
    /// Kept rather than rebuilt because a session is a *place in a queue*: a reader who answers
    /// two cards, follows a thought into the reading screen and comes back should find the third
    /// card, not the first one again.
    func hadithMemorizeViewModel() -> HadithMemorizeViewModel {
        if let cachedHadithMemorizeViewModel {
            return cachedHadithMemorizeViewModel
        }

        let viewModel = HadithMemorizeViewModel(useCase: memorizeHadith, clock: clock)
        cachedHadithMemorizeViewModel = viewModel
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

        let viewModel = AdhkarViewModel(
            useCase: getAdhkar,
            settingsStore: settingsStore,
            activity: activityRecorder
        )
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
