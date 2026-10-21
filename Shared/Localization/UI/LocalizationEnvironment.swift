//
//  LocalizationEnvironment.swift
//  ThawabForGod
//

import SwiftUI

extension View {
    /// Puts the localization manager in the environment at the root of a scene. Call once,
    /// next to `.themed(_:)`.
    ///
    /// It deliberately does **not** set `\.locale`, and on iOS not `\.layoutDirection` either (on macOS it
    /// does, once, from the launch language: see the note in the modifier). It used to, back when
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
            #if os(macOS)
            // The Mac's window chrome stays as macOS draws it, and under `-AppleLanguages (ar)` it
            // does not mirror (BUGS.md B7: `Bundle.main.preferredLocalizations` is `["ar"]` while
            // `NSApp.userInterfaceLayoutDirection` is still left-to-right), so the content follows
            // `AppLanguage` instead. This is set once, from the language the process launched in,
            // and never flipped under a live view: the `Form` problem above needs a *change*.
            .environment(\.layoutDirection, AppLanguage.current() == .arabic ? .rightToLeft : .leftToRight)
            #endif
    }
}
