//
//  MainInterfaceView.swift
//  ThawabForGod
//

import SwiftUI

/// The main interface, in whichever arrangement the window is wide enough for.
///
/// A tab bar when the width is compact — every iPhone, and an iPad in Slide Over or the narrow
/// half of a Split View — and a sidebar when it is not. The Mac has no size classes and is never
/// the compact case, so it goes straight to the sidebar.
///
/// **The switch really does rebuild the subtree**, and that is fine here for one reason: none of
/// the navigation state is in it. Every stack's path lives on its coordinator, and the selected
/// section lives on `AppRouter`, both held by `AppContainer` — so an iPad rotated from portrait
/// to landscape, or dragged from a third of the screen to two, redraws into the other arrangement
/// with every section still on the screen it was left on. Had the paths been `@State` in the
/// views, the same rotation would have thrown them all away.
///
/// This is deliberately *not* `NavigationSplitView`'s own compact behaviour, which collapses to a
/// single stack rooted at the sidebar list. That would cost the iPhone its tab bar and put a
/// "back to the list of sections" step in front of every screen in the app.
struct MainInterfaceView: View {
    let container: AppContainer

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            MainTabView(container: container)
        } else {
            MainSplitView(container: container)
        }
        #else
        MainSplitView(container: container)
        #endif
    }
}
