//
//  MainSplitView.swift
//  ThawabForGod
//

import SwiftUI

/// The wide arrangement: the sections down a sidebar, the chosen one filling the detail column.
///
/// This is what the Mac always gets and what an iPad gets at regular width. It is the same set of
/// sections the tab bar shows, in the same order, drawn from the same `AppTab.visible` — only the
/// arrangement differs, which is why `AppSectionView` holds the content and these two files hold
/// nothing but their own shape.
///
/// **Two columns, not three.** A third column would mean each section handing its list to the
/// sidebar's neighbour and keeping only its leaf — a different navigation model per section,
/// since Home has no list to give, the Quran has one level and the hadith have two. The detail
/// column keeps each section's own `NavigationStack` instead, so a push means the same thing at
/// every width and the iPad and the iPhone stay one app rather than two.
///
/// The selection is the router's, not a `@State` here. That is what lets the iPad rotate — or a
/// Split View widen — without the user landing somewhere they did not choose: `MainInterfaceView`
/// swaps this view for `MainTabView` and the selection is still where they left it.
struct MainSplitView: View {
    let container: AppContainer

    @Environment(LocalizationManager.self) private var l10n

    /// Owned here rather than on the router because it is genuinely view state: which columns are
    /// showing is a property of *this* arrangement, and the tab bar has no opinion about it.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppTab.visible, id: \.self, selection: selection) { tab in
                Label(l10n.string(tab.titleKey), systemImage: tab.symbol)
                    .tag(tab)
            }
            .navigationTitle(l10n.string(.appName))
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            AppSectionView(container: container, tab: container.router.selectedTab)
        }
        // `.balanced` rather than the default `.prominentDetail`: the sidebar is four or five
        // rows the reader picks from, not a panel that should shove the page aside to appear.
        .navigationSplitViewStyle(.balanced)
    }

    /// The router's selection, as the optional binding a single-selection `List` asks for.
    ///
    /// A `nil` write is dropped rather than stored. macOS lets a click land in the empty space
    /// below the rows and clears the selection; the router has no "no section" to represent, and
    /// an empty detail column is not a place the reader asked to be.
    private var selection: Binding<AppTab?> {
        Binding(
            get: { container.router.selectedTab },
            set: { if let tab = $0 { container.router.selectedTab = tab } }
        )
    }
}
