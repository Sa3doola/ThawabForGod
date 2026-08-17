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
/// A `Form` on all three platforms. On iPhone and iPad it is pushed onto the stack Home owns; on
/// macOS the same view is the content of the `Settings` scene, reached with ⌘, where a Mac user
/// expects to find it. `.formStyle(.grouped)` is what makes the second of those look native
/// rather than like a phone screen in a window.
struct SettingsView: View {
    let viewModel: SettingsViewModel
    let coordinator: SettingsCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Form {
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
        // Pushes into whichever stack encloses this screen: Home's on iOS, the one the Settings
        // scene puts up on macOS. Two-way, so a back swipe writes `nil` and the coordinator
        // follows — the same idiom the names grid uses.
        .navigationDestination(item: openDestination) { destination in
            switch destination {
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
            coordinator: SettingsCoordinator()
        )
    }
    .themed(themeManager)
    .localized(localizationManager)
}
