//
//  FadeMask.swift
//  ThawabForGod
//

import SwiftUI

/// A mask that fades its content out towards one edge — the soft bottom of a clipped tafsir or
/// ayah-panel preview that says "there is more".
///
/// **The one place a literal colour is allowed, and why it is not a colour.** A mask reads only
/// the alpha of what it is given and throws the colour away, so the gradient below runs from
/// opaque `.black` to `.clear` purely to say "keep" and "drop". It is never seen, it does not
/// change with the theme, and no palette token would mean anything here — but a reviewer grepping
/// for `.black` deserves to find this paragraph rather than a mystery (QURAN_MIGRATION_PLAN.md,
/// T9). Mushaf drew this gradient inline in two views; here both use this one.
nonisolated struct FadeMask: View {
    /// The edge the content fades towards.
    var edge: VerticalEdge = .bottom
    /// How much of the height the fade takes, from that edge: 0 is a hard cut, 1 fades all the way.
    var fadeFraction: CGFloat = 0.25

    var body: some View {
        let fade = min(max(fadeFraction, 0), 1)
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 1 - fade),
                .init(color: .clear, location: 1),
            ],
            startPoint: edge == .bottom ? .top : .bottom,
            endPoint: edge == .bottom ? .bottom : .top
        )
    }
}

extension View {
    /// Fades this view out towards `edge` over `fadeFraction` of its height. See `FadeMask`.
    func fadeMask(_ edge: VerticalEdge = .bottom, fadeFraction: CGFloat = 0.25) -> some View {
        mask(FadeMask(edge: edge, fadeFraction: fadeFraction))
    }
}
