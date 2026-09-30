//
//  ThawabForGodApp.swift
//  ThawabForGod
//
//  Created by Saad Sherif on 10/08/2026.
//

import SwiftData // `.modelContainer(_:)`; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import SwiftUI

@main
struct ThawabForGodApp: App {
    @State private var container = AppContainer()

    // Both platforms want an application delegate, and for related but not identical reasons.
    // iOS needs one so it can supply a scene configuration: a Home Screen quick action arrives
    // as a `UIApplicationShortcutItem` on a `UIWindowSceneDelegate`, and a SwiftUI app has no
    // scene delegate unless it asks for one. macOS needs one because `applicationDockMenu(_:)`
    // is the only way to put anything in the Dock menu. Neither delegate routes anything — see
    // `DeepLinkInbox`.
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    /// The bundled faces are registered before anything can ask for one: the scene's body has not
    /// been evaluated yet, so no `Font.custom` has had the chance to resolve against a name
    /// CoreText does not know and quietly substitute the system face.
    init() {
        FontRegistrar.registerBundledFonts()
        #if os(iOS)
        ChromeTypography.apply()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 480)
                #endif
                .themed(container.themeManager, fonts: PlexAppFont())
                .localized(container.localizationManager)
        }
        .modelContainer(container.persistence.container)
        #if os(macOS)
        // A Mac window opens at a size someone would actually read in, and refuses to be dragged
        // smaller than the sidebar plus a column of verses. `.contentMinSize` is what makes the
        // green zoom button and the resize handles respect the `minWidth`/`minHeight` below
        // rather than the content's own idea of how small it could squeeze.
        .defaultSize(width: 1_100, height: 760)
        .windowResizability(.contentMinSize)
        .commands { SectionCommands(container: container) }
        #endif

        #if os(macOS)
        // The Mac idiom, and the reason the toolbar gear is `#if os(iOS)`: a Mac user looks for
        // preferences under the app menu and ⌘,, not in the window. The same `SettingsView` fills
        // it, in a `NavigationStack` of its own so the sources screen has somewhere to push to —
        // this scene is not inside the one `RootView` puts up.
        //
        // No `.modelContainer(_:)`: nothing on this screen touches SwiftData.
        Settings {
            @Bindable var coordinator = container.settingsCoordinator

            NavigationStack(path: $coordinator.path) {
                SettingsView(
                    container: container.settings,
                    coordinator: container.settingsCoordinator
                )
            }
            // The tabbed window sizes itself — see `SettingsView.presentation` — so this only
            // has to stop the scene squeezing it.
            .frame(minWidth: 720, minHeight: 540)
            .themed(container.themeManager, fonts: PlexAppFont())
            .localized(container.localizationManager)
        }
        #endif
    }
}

#if os(macOS)
/// ⌘1 … ⌘4 for the sections, under View, where the Mac keeps its "go to that part of the window"
/// commands.
///
/// The Mac's sidebar is the only presentation with no equivalent of a tab bar's muscle memory, so
/// the shortcuts are the keyboard support the plan asks for rather than a decoration. They write
/// the same `AppRouter.selectedTab` the sidebar's own selection does — the router is the single
/// place that answers "which section", which is what lets a menu command move the window without
/// reaching into the view hierarchy.
///
/// Numbered from `AppTab.visible`, so a section added or removed renumbers the menu with it.
private struct SectionCommands: Commands {
    let container: AppContainer

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()

            ForEach(Array(AppTab.visible.enumerated()), id: \.element) { index, tab in
                Button(container.localizationManager.string(tab.titleKey)) {
                    container.router.selectedTab = tab
                }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(index + 1)")),
                    modifiers: .command
                )
            }
        }
    }
}
#endif
