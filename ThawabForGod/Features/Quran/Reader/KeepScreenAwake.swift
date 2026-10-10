//
//  KeepScreenAwake.swift
//  ThawabForGod
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Holds the idle timer off while this view is on screen and `isOn` is `true`.
    ///
    /// **Scoped to the view rather than set once and forgotten.** `isIdleTimerDisabled` is a
    /// property of the whole application, so a screen that sets it on the way in and never clears
    /// it leaves a phone that will not sleep for the rest of the session — which is the failure
    /// this modifier exists to make impossible: leaving the view clears it, whether the reader
    /// navigated away, backgrounded the app, or turned the switch off.
    ///
    /// It also has to survive the app going to the background and coming back. iOS clears the
    /// flag itself on deactivation, so the value is re-applied on `scenePhase` returning to
    /// `.active` rather than only on appear.
    ///
    /// A no-op on macOS, where there is no idle timer to disable and a Mac's own sleep settings
    /// are the user's business rather than an app's.
    ///
    /// **In the app target rather than `Shared/`**, though it is otherwise the kind of generic
    /// modifier that belongs beside the design system: `UIApplication.shared` is unavailable in
    /// an app extension, and everything in `Shared/` is compiled into the widget as well. It
    /// lives beside its one caller until a second screen wants it.
    func keepScreenAwake(_ isOn: Bool) -> some View {
        modifier(KeepScreenAwakeModifier(isOn: isOn))
    }
}

private struct KeepScreenAwakeModifier: ViewModifier {
    let isOn: Bool

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            #if canImport(UIKit)
            .onAppear { apply(isOn) }
            .onDisappear { apply(false) }
            .onChange(of: isOn) { _, isOn in apply(isOn) }
            .onChange(of: scenePhase) { _, phase in apply(phase == .active && isOn) }
            #endif
    }

    #if canImport(UIKit)
    private func apply(_ isOn: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isOn
    }
    #endif
}
