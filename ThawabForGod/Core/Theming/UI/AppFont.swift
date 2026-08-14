//
//  AppFont.swift
//  ThawabForGod
//

import SwiftUI

/// Supplies a `Font` for each step of the type scale.
///
/// A protocol rather than a bare enum so a bespoke Arabic face can be swapped in later
/// without touching a single call site.
nonisolated protocol AppFontProviding: Sendable {
    func font(_ style: AppTextStyle, weight: Font.Weight) -> Font
}

nonisolated extension AppFontProviding {
    func font(_ style: AppTextStyle) -> Font {
        font(style, weight: .regular)
    }
}

/// Default provider: the system face, which resolves to SF Arabic for Arabic text.
/// Built on `Font.TextStyle`, so every size follows Dynamic Type.
nonisolated struct SystemAppFont: AppFontProviding {
    func font(_ style: AppTextStyle, weight: Font.Weight) -> Font {
        .system(style.textStyle, design: .default).weight(weight)
    }
}

// Extensions pick up the module's `MainActor` default isolation, so this one opts out —
// the type it extends is `nonisolated` and the mapping is pure.
nonisolated extension AppTextStyle {
    var textStyle: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption
        }
    }
}

extension View {
    /// Applies a step of the app's type scale. Use this instead of `.font(...)`.
    func appFont(_ style: AppTextStyle, weight: Font.Weight = .regular) -> some View {
        modifier(AppFontModifier(style: style, weight: weight))
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appFont) private var provider
    let style: AppTextStyle
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(provider.font(style, weight: weight))
    }
}
