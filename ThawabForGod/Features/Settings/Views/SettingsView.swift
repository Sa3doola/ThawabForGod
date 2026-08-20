//
//  SettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// Every preference the app has, in one grouped list.
///
/// The screen holds no preference of its own. Each section writes through `SettingsViewModel` to
/// the object that already owns that concern — `ThemeManager`, `LocalizationManager`,
/// `CalculationSettings` — all three of which persist through `SettingsStore` and are applied at
/// the root, so a change here is a change everywhere rather than a change that has to be
/// propagated.
///
/// A `Form` on all three platforms. On iPhone and iPad it is the root of its own tab; on macOS
/// the same view is the content of the `Settings` scene, reached with ⌘, where a Mac user expects
/// to find it — which is why there is no settings tab in that build. `.formStyle(.grouped)` is
/// what makes the second of those look native rather than like a phone screen in a window.
struct SettingsView: View {
    let viewModel: SettingsViewModel
    let coordinator: SettingsCoordinator

    /// The Home-arranging screen, which Settings pushes and Home also pushes onto its own stack.
    /// One instance, handed to both — see `AppContainer.homeCustomizationViewModel()`.
    let customizationViewModel: HomeCustomizationViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Form {
            // First, because it is the only row here that changes what the user *sees* rather
            // than how something is computed — and because Home is where they just came from.
            Section {
                SettingsDisclosureRow(titleKey: .homeCustomizeTitle) {
                    coordinator.show(.homeCustomization)
                }
            }

            AppearanceSettingsSection(viewModel: viewModel)
            FormatSettingsSection(viewModel: viewModel)
            CalculationSettingsSection(viewModel: viewModel)
            RemindersSettingsSection(viewModel: viewModel)
            TipsSettingsSection(viewModel: viewModel)
            AboutSettingsSection(viewModel: viewModel) {
                coordinator.show(.sources)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsTitle))
        // Re-read on each appearance rather than once: notification permission can be revoked
        // in the Settings app while this app sits in the background.
        .task { await viewModel.loadNotificationStatus() }
        // Pushes into whichever stack encloses this screen: the settings tab's on iOS, the one
        // the Settings scene puts up on macOS. Two-way, so a back swipe writes `nil` and the
        // coordinator follows — the same idiom the names grid uses.
        .navigationDestination(item: openDestination) { destination in
            switch destination {
            case .homeCustomization:
                HomeCustomizationView(viewModel: customizationViewModel)

            case .sources:
                SourcesView(sources: viewModel.sources)
            }
        }
    }

    /// Built here rather than reached for with `@Bindable`, because the coordinator exposes its
    /// destination read-only — so a dismissal by swipe goes through the same method a Back button
    /// would call.
    private var openDestination: Binding<SettingsCoordinator.Destination?> {
        Binding(
            get: { coordinator.destination },
            set: { if $0 == nil { coordinator.close() } }
        )
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()
    let layoutRepository = HomeLayoutRepository(settingsStore: settingsStore)
    let themeManager = ThemeManager(settingsStore: settingsStore)
    let localizationManager = LocalizationManager(
        settingsStore: settingsStore,
        numberFormatting: LocaleNumberFormattingService(),
        timeFormatting: LocaleTimeFormattingService()
    )

    NavigationStack {
        SettingsView(
            viewModel: SettingsViewModel(
                theme: themeManager,
                localization: localizationManager,
                calculation: CalculationSettings(config: .default, settingsStore: settingsStore),
                reminders: ReminderPreferences(settingsStore: settingsStore),
                // The real service, but pointed at nothing the preview can disturb: it only
                // ever gets asked for the authorization status here.
                notifications: UserNotificationService(
                    center: UserNotificationCenterClient(),
                    planner: PrayerReminderPlanner(
                        repository: PrayerTimeRepository(engine: PrayerTimeEngine())
                    ),
                    content: LocalizedReminderContent(l10n: localizationManager),
                    inputs: AppReminderInputs(
                        location: CoreLocationService(),
                        settingsStore: settingsStore
                    )
                ),
                resetTips: ResetTipsUseCase(tips: TipsService())
            ),
            coordinator: SettingsCoordinator(),
            customizationViewModel: HomeCustomizationViewModel(
                getLayout: GetHomeLayoutUseCase(repository: layoutRepository),
                updateLayout: UpdateHomeLayoutUseCase(repository: layoutRepository),
                resetLayout: ResetHomeLayoutUseCase(repository: layoutRepository)
            )
        )
    }
    .themed(themeManager)
    .localized(localizationManager)
}
