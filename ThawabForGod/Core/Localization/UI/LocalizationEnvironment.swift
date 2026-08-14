//
//  LocalizationEnvironment.swift
//  ThawabForGod
//

import SwiftUI

extension View {
    /// Applies the user's language at the root of a scene: the manager itself, the locale
    /// that drives date and number formatting, and the layout direction that mirrors every
    /// screen for Arabic. Call once, next to `.themed(_:)`.
    func localized(_ manager: LocalizationManager) -> some View {
        modifier(LocalizedModifier(manager: manager))
    }
}

private struct LocalizedModifier: ViewModifier {
    let manager: LocalizationManager

    func body(content: Content) -> some View {
        content
            .environment(manager)
            .environment(\.locale, manager.locale)
            .environment(\.layoutDirection, manager.layoutDirection)
    }
}
