//
//  MainTabView.swift
//  ThawabForGod
//

import SwiftUI

/// The compact arrangement: one tab per section, each owning a navigation stack of its own.
///
/// This is what an iPhone gets, and what an iPad gets when it is narrow — half a Split View, a
/// Slide Over. The wide arrangement is `MainSplitView`; `MainInterfaceView` picks between them,
/// and `AppSectionView` is the content both of them show, so this file is only about the
/// *arrangement*.
///
/// **`.tabItem` rather than the `Tab` value builder**, which is iOS 18. The deployment target is
/// iOS 17, so this is the API that exists.
struct MainTabView: View {
    let container: AppContainer

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        // The selection lives on the router, so a deep link can move the user between sections
        // without this view being involved — and so the sidebar and the tab bar agree about
        // where the user is when the iPad swaps one for the other. `@Bindable` is what turns
        // that into a binding.
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.visible, id: \.self) { tab in
                AppSectionView(container: container, tab: tab)
                    .tabItem { Label(l10n.string(tab.titleKey), systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
    }
}
