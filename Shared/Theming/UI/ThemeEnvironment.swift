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
    ///
    /// `fonts` defaults to the system face so a preview, or a process that has not registered the
    /// bundled faces, draws with something real rather than CoreText's silent fallback. The app
    /// passes `PlexAppFont()`, having registered it first.
    func themed(
        _ manager: ThemeManager,
        fonts: any AppFontProviding = SystemAppFont()
    ) -> some View {
        modifier(ThemedModifier(manager: manager, fonts: fonts))
    }
}

private struct ThemedModifier: ViewModifier {
    let manager: ThemeManager
    let fonts: any AppFontProviding

    func body(content: Content) -> some View {
        content
            .environment(manager)
            .environment(\.theme, manager.theme)
            .environment(\.appFont, fonts)
            // The face every `Text` inherits when nothing nearer says otherwise — a `Form` row's
            // label, a `Toggle`, a `Button` in a toolbar. Without it those would stay in the
            // system face while everything set through `appFont(_:weight:)` changed around them.
            .font(fonts.font(.body))
            .tint(manager.theme.accent)
            .preferredColorScheme(manager.appearance.colorScheme)
    }
}
