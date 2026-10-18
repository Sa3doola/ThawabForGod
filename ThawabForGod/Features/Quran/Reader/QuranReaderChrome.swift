//
//  QuranReaderChrome.swift
//  ThawabForGod
//

import SwiftUI

// The platform glue for the reader's bars: the one file in the Quran feature that says `#if os`,
// so that no view has to. Two jobs, one placement list each: Q3 (the bars take the page's colours)
// and immersive reading (the bars go away). See docs/quran-migration/design/M5.1.md, 4.6 and 4.7.
//
// **Two rules a later reader must not break.**
//
// 1. No `preferredColorScheme` in the Quran feature. It propagates *up*, to the whole window, so
//    the sidebar, the other tabs and the status bar would turn with the page. Mushaf could use it
//    because its reader was the window; here the reader is one screen of several. The surface
//    scopes `\.colorScheme` to the page with `.environment`, which only goes down.
// 2. No `UINavigationBar.appearance()` or `UITabBar.appearance()` either. They are global, they do
//    not update bars already on screen, and every way out of the reader would have to undo them by
//    hand. The toolbar modifiers below belong to the view that declares them and are in force
//    only while it is the screen in front, so there is nothing to restore and nothing to leak.
//
// **Unverified at run time** (the design note's section 7 lists the checks and the fallbacks, and
// each fallback is a change inside this file):
//
// - Whether iOS 26's glass bars are painted, tinted or left alone by `toolbarBackground`. Correct
//   either way, because the page's paper already extends behind the bars.
// - Whether the tab bar follows the reader's preferences when the tab is switched. `isActive` is
//   there so the answer does not matter: the caller turns it off on `onDisappear`.
// - Whether `statusBarHidden` on the section's stack takes effect inside a `TabView`. If it does
//   not, make `quranSectionChrome` return `self`; the status bar then stays and the page's paper
//   is behind it.
// - Whether the Mac's `.windowToolbar` placement also paints the sidebar's title-bar area. If it
//   does, delete that placement from `QuranReaderBarsModifier`.
// - Whether hiding the tab bar on a screen already pushed moves the page's safe area. No manual
//   inset is added if it does not.

extension View {
    /// Q3: the bars around the reader take the page's colours while `isActive`.
    ///
    /// When it is not active the modifiers ask for the system's own look (`.automatic`, no colour
    /// scheme), so giving the bars back is something this code says rather than something it relies
    /// on preference scoping to do.
    func quranReaderBars(_ palette: ReadingPalette, isActive: Bool) -> some View {
        modifier(QuranReaderBarsModifier(palette: palette, isActive: isActive))
    }

    /// The reader's own Library button replaces the system back button, and with it the edge swipe
    /// that would fight the pager: a page turn starts at the same screen edge as a pop.
    func quranReaderHidesSystemBack() -> some View {
        navigationBarBackButtonHidden(true)
    }

    /// Immersive reading: the navigation bar and the tab bar. On the reader screen. A no-op on
    /// macOS, which has no immersive mode.
    func quranImmersiveBars(hidden: Bool) -> some View {
        #if os(iOS)
        return modifier(QuranImmersiveBarsModifier(hidden: hidden))
        #else
        return self
        #endif
    }

    /// Immersive reading: the status bar and the home indicator. On the Quran section's
    /// `NavigationStack`, where the setting takes effect.
    func quranSectionChrome(coordinator: QuranCoordinator, viewModel: QuranReaderViewModel) -> some View {
        modifier(QuranSectionChromeModifier(coordinator: coordinator, viewModel: viewModel))
    }
}

#if os(iOS)
/// The navigation bar follows `hidden`; the tab bar also goes at compact height on iPhone (landscape),
/// where about 390 pt of screen cannot spare a bar.
private struct QuranImmersiveBarsModifier: ViewModifier {
    let hidden: Bool

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        let tabBarHidden = hidden || (DeviceKind.isPhone && verticalSizeClass == .compact)
        // `.toolbar(_:for:)` is the iOS 16 spelling; `toolbarVisibility` is iOS 18.
        content
            .toolbar(hidden ? .hidden : .automatic, for: .navigationBar)
            .toolbar(tabBarHidden ? .hidden : .automatic, for: .tabBar)
    }
}
#endif

private struct QuranReaderBarsModifier: ViewModifier {
    let palette: ReadingPalette
    let isActive: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .toolbarBackground(palette.background, for: .navigationBar, .tabBar)
            .toolbarBackground(isActive ? .visible : .automatic, for: .navigationBar, .tabBar)
            .toolbarColorScheme(isActive ? palette.colorScheme : nil, for: .navigationBar, .tabBar)
        #else
        content
            .toolbarBackground(palette.background, for: .windowToolbar)
            .toolbarBackground(isActive ? .visible : .automatic, for: .windowToolbar)
            .toolbarColorScheme(isActive ? palette.colorScheme : nil, for: .windowToolbar)
        #endif
    }
}

private struct QuranSectionChromeModifier: ViewModifier {
    let coordinator: QuranCoordinator
    let viewModel: QuranReaderViewModel

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning

    func body(content: Content) -> some View {
        #if os(iOS)
        // `coordinator.isReaderOnTop` is the "this reader is the screen in front" half; the view
        // model answers the rest. Both are read here so the hidden state is true the instant
        // either changes.
        let hidden = coordinator.isReaderOnTop && viewModel.isImmersive(voiceOverRunning: voiceOverRunning)
        content
            .statusBarHidden(hidden)
            .persistentSystemOverlays(hidden ? .hidden : .automatic)
        #else
        content
        #endif
    }
}
