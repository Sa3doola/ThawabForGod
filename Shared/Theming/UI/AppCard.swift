//
//  AppCard.swift
//  ThawabForGod
//

import SwiftUI

/// A surface, the way this design draws one: the `Surface` token, a radius from the scale, a
/// hairline in `Separator`, and one step of elevation.
///
/// **All four together, or none of them.** They were written out by hand at twenty-five call
/// sites, and the drift was exactly what you would expect — some rows had the border and no
/// shadow, some had the shadow and no border, and the radius came from six different numbers.
/// None of that is visible one screen at a time; all of it is visible on a screen showing two
/// of them.
///
/// The hairline is doing real work rather than decorating. On the dark ground the shadow is drawn
/// as nothing (see `AppElevation`), so the border is the *only* thing separating a `#1A1816`
/// surface from a `#0E0D0C` page — which is a difference of twelve values and would otherwise be
/// no edge at all.
extension View {
    /// - Parameters:
    ///   - radius: from `AppRadius`. `lg` is a card and is what almost everything wants; `md` is
    ///     for a surface nested inside another one, where the outer radius has already been spent.
    ///   - elevation: `card` unless this is a sheet or a popover.
    ///   - isOutlined: whether to draw the hairline. The one case that passes `false` is a
    ///     surface already inside a bordered one, where a second rule reads as a seam.
    func appCard(
        radius: CGFloat = AppRadius.lg,
        elevation: AppElevation = .card,
        isOutlined: Bool = true
    ) -> some View {
        modifier(AppCardModifier(radius: radius, elevation: elevation, isOutlined: isOutlined))
    }
}

private struct AppCardModifier: ViewModifier {
    @Environment(\.theme) private var theme

    let radius: CGFloat
    let elevation: AppElevation
    let isOutlined: Bool

    func body(content: Content) -> some View {
        content
            .background(theme.surface, in: .rect(cornerRadius: radius))
            .overlay {
                if isOutlined {
                    RoundedRectangle(cornerRadius: radius).strokeBorder(theme.separator)
                }
            }
            .appElevation(elevation)
    }
}
