//
//  AppTapTarget.swift
//  ThawabForGod
//

import SwiftUI

extension View {
    /// Grows a control's hit area to the platform's minimum without growing what is drawn.
    ///
    /// **The two sizes are separate on purpose.** A symbol-only button in a dense list wants to
    /// be small — the bookmark under a verse sits below all 286 of Al-Baqara's and must not
    /// compete with them — but a fingertip is about nine millimetres across and does not care
    /// what the symbol looks like. So the glyph keeps whatever frame it was given and this adds
    /// room around it, which is the arrangement Apple's 44-point rule actually asks for: the
    /// *target* is 44, the artwork need not be.
    ///
    /// The `contentShape` is applied after the frame rather than before it, so the whole padded
    /// box is tappable and not merely the glyph in the middle of it. Without that the frame
    /// would reserve the space and then decline to take taps in it, which is the worst of both.
    ///
    /// The number is the platform's — 44 for a fingertip, 28 for a cursor — and lives in
    /// `AppBreakpoint.minimumTapTarget` beside the other measurements the design fixes.
    func minimumTapTarget() -> some View {
        frame(
            minWidth: AppBreakpoint.minimumTapTarget,
            minHeight: AppBreakpoint.minimumTapTarget
        )
        .contentShape(.rect)
    }
}
