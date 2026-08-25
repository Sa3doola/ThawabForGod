//
//  SettingsView.swift
//  ThawabForGod
//

import SwiftUI

/// Settings' root: seven rows, each opening a screen about one subject.
///
/// It was one long `Form` until it grew past four groups. A list you have to scroll to find the
/// thing you came for has outgrown being a list — and the groups had stopped being comparable
/// anyway: an accent swatch and a rolling notification window are not two settings of the same
/// kind, and putting them in one column implied they were.
///
/// **This screen owns nothing.** Every preference belongs to a manager built at the composition
/// root — `ThemeManager`, `LocalizationManager`, `CalculationSettings`, `ReminderPreferences` —
/// all of which persist through `SettingsStore`. The sub-screens forward to those; this one only
/// routes.
///
/// **The same routes on all three platforms, drawn as the platform draws preferences.** On
/// iPhone and iPad this is the root of its own tab: grouped rows that push. On macOS it is the
/// content of the `Settings` scene, reached with ⌘, where a Mac user expects to find it — which
/// is why there is no settings tab in that build — and there it is a *tabbed* window, because a
/// list of rows that pushes is not what a Mac preferences window is.
///
/// The branch is over the presentation alone. Both arrangements iterate `SettingsRoute.root` and
/// both build their screens with `screen(for:)`, so a route added to the enum appears in both
/// without either being edited: the enum already carries a title and a symbol per case, which is
/// exactly what a row needs and exactly what a tab item needs.
struct SettingsView: View {
    let container: SettingsScreens

    @Bindable var coordinator: SettingsCoordinator

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        presentation
            .navigationTitle(l10n.string(.settingsTitle))
            // One destination for the whole path, so `about` can push `sources` without either
            // screen knowing how deep it is — on the Mac too, where the push covers the tabbed
            // window rather than sliding beside it.
            .navigationDestination(for: SettingsRoute.self, destination: screen)
    }

    #if os(macOS)
    /// A tabbed preferences window, at the size the design specifies.
    ///
    /// Fixed rather than resizable: every one of these panes is a short column of controls, and a
    /// preferences window a user has to size themselves is one more thing to have an opinion
    /// about. The number is the design's — 720 × 540.
    private var presentation: some View {
        TabView {
            ForEach(SettingsRoute.root, id: \.self) { route in
                screen(for: route)
                    .tabItem {
                        Label(l10n.string(route.titleKey), systemImage: route.symbol)
                    }
            }
        }
        .frame(width: 720, height: 540)
    }
    #else
    /// Grouped rows that push, which is what a preference screen is on a phone.
    private var presentation: some View {
        Form {
            Section {
                ForEach(SettingsRoute.root, id: \.self) { route in
                    SettingsIconRow(route: route) { coordinator.show(route) }
                }
            }
        }
        .formStyle(.grouped)
    }
    #endif

    @ViewBuilder
    private func screen(for route: SettingsRoute) -> some View {
        switch route {
        case .homeCustomization:
            HomeCustomizationView(viewModel: container.homeCustomization)

        case .appearance:
            AppearanceSettingsView(viewModel: container.appearance)

        case .languageAndFormat:
            LanguageFormatSettingsView(viewModel: container.languageAndFormat)

        case .prayerCalculation:
            PrayerCalculationSettingsView(viewModel: container.prayerCalculation)

        case .reminders:
            RemindersSettingsView(viewModel: container.reminders)

        case .tips:
            TipsSettingsView(viewModel: container.tips)

        case .macIntegration:
            #if os(macOS)
            MacSettingsView(viewModel: container.macIntegration)
            #endif

        case .about:
            AboutView(viewModel: container.about) { coordinator.show(.sources) }

        case .sources:
            SourcesView(sources: container.about.sources)
        }
    }
}

/// What Settings needs to build its screens.
///
/// A protocol rather than passing seven view models down, and rather than handing this view the
/// whole `AppContainer`: the root's job is to route, and a route is answered by a view model it
/// does not otherwise care about. `AppContainer` conforms, so the wiring stays at the composition
/// root while this file names only what it uses.
@MainActor
protocol SettingsScreens {
    var homeCustomization: HomeCustomizationViewModel { get }
    var appearance: AppearanceSettingsViewModel { get }
    var languageAndFormat: LanguageFormatSettingsViewModel { get }
    var prayerCalculation: PrayerCalculationSettingsViewModel { get }
    var reminders: RemindersSettingsViewModel { get }
    var tips: TipsSettingsViewModel { get }
    var about: AboutViewModel { get }

    /// macOS only, because the screen behind it is — `SettingsRoute.macIntegration` is filtered
    /// out of the root on iOS, so nothing there ever asks for this.
    #if os(macOS)
    var macIntegration: MacSettingsViewModel { get }
    #endif
}
