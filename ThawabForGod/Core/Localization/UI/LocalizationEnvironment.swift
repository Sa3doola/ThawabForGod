//
//  LocalizationEnvironment.swift
//  ThawabForGod
//

import SwiftUI

extension View {
    /// Puts the localization manager in the environment at the root of a scene. Call once,
    /// next to `.themed(_:)`.
    ///
    /// It deliberately does **not** set `\.locale` or `\.layoutDirection`. It used to, back when
    /// the app carried its own language switcher, and that was the bug: overriding the layout
    /// direction under a live `Form` or `List` leaves the UIKit mirroring transform those views
    /// set up at creation in place, and every glyph renders backwards.
    ///
    /// The language now comes from the system — see `AppLanguage.current(in:)` — so the process
    /// launches with the correct locale and direction already applied, all the way down, by the
    /// same machinery that gets it right for every other localized app. There is nothing left
    /// here to override, and overriding it was never the app's business.
    func localized(_ manager: LocalizationManager) -> some View {
        modifier(LocalizedModifier(manager: manager))
    }
}

private struct LocalizedModifier: ViewModifier {
    let manager: LocalizationManager

    func body(content: Content) -> some View {
        content
            .environment(manager)
    }
}
