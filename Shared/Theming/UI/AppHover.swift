//
//  AppHover.swift
//  ThawabForGod
//

import SwiftUI

/// The pointer's answer to a press: a wash over the whole row while the cursor is on it.
///
/// **`Primary` at six per cent, never the accent.** The accent means *selected* — the active tab,
/// the chosen swatch, the verse a search landed on — and a row that tinted itself with the same
/// colour on hover would say "this is selected" about whatever the pointer happened to be
/// crossing. A neutral wash says "this one" and nothing more, which is all a hover ever means.
///
/// Not `#if os(macOS)`. An iPad with a trackpad or a Magic Keyboard has a pointer and hovers
/// exactly the way a Mac does, and gating this on the platform would leave that iPad the one
/// device where rows do not respond to a cursor. A touch never fires `onHover`, so a phone pays
/// nothing for it being here.
///
/// The radius has to be passed in rather than defaulted from `AppCard`, because the wash is drawn
/// *over* the card and a wash rounder or squarer than the thing it covers is worse than no wash.
extension View {
    func appHover(radius: CGFloat = AppRadius.lg) -> some View {
        modifier(AppHoverModifier(radius: radius))
    }
}

private struct AppHoverModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @State private var isHovering = false

    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if isHovering {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(theme.primary.opacity(0.06))
                        // The wash is a hint, not a target — a pointer must still reach what is
                        // underneath it.
                        .allowsHitTesting(false)
                }
            }
            .onHover { isHovering = $0 }
            // Instant on, and a beat to fade out. A wash that animated in would lag the pointer
            // across a list; one that vanished would flicker between two adjacent rows.
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
