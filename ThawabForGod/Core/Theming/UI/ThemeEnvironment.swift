//
//  ThemeEnvironment.swift
//  ThawabForGod
//

import SwiftUI

extension EnvironmentValues {
    @Entry var theme: Theme = .fallback
    @Entry var appFont: any AppFontProviding = SystemAppFont()
    /// Resolved by the reading screen from the reader's saved choices; `fallback` everywhere
    /// else, which is the app's own palette at the app's own size.
    @Entry var readingStyle: ReadingStyle = .fallback
}

nonisolated extension AppearanceOverride {
    /// `nil` means "follow the system", which is what `preferredColorScheme` expects.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension View {
    /// Applies the design system at the root of a scene: palette, type scale, tint and
    /// appearance override. Call once, in `ThawabForGodApp`.
    func themed(_ manager: ThemeManager) -> some View {
        modifier(ThemedModifier(manager: manager))
    }
}

private struct ThemedModifier: ViewModifier {
    let manager: ThemeManager

    func body(content: Content) -> some View {
        content
            .environment(manager)
            .environment(\.theme, manager.theme)
            .environment(\.appFont, SystemAppFont())
            .tint(manager.theme.accent)
            .preferredColorScheme(manager.appearance.colorScheme)
    }
}
