//
//  ReadingStyle.swift
//  ThawabForGod
//

import SwiftUI

/// The colours of a page of scripture.
///
/// A parallel to `Theme` rather than a slice of it, and separate for one reason: a paper is
/// chosen against *the page*, where `Theme` is chosen against the app. That includes the accent —
/// the app's amber reads well on the app's own background and washes out entirely on parchment,
/// so a paper that fixes its background fixes its ink with it. Picking a named paper therefore
/// sets the accent aside for the length of the reading; picking `.system` gives it straight back.
nonisolated struct ReadingPalette: Equatable, Sendable {
    var background: Color
    var textPrimary: Color
    var textSecondary: Color

    /// Verse numbers, the basmala and the sajda mark — the ornament of the page rather than its
    /// text.
    var accent: Color
}

/// Everything the reading screen needs to draw itself the way the reader asked for.
///
/// Passed through the environment rather than down through initialisers because `VerseRow` is
/// three levels below the screen that resolves it, and the sheet that edits it is presented from
/// the top — so the value has to reach a leaf without every view in between naming it.
nonisolated struct ReadingStyle: Equatable, Sendable {
    var palette: ReadingPalette
    var typography: ReaderTypography
    var font: ReaderFont = .fallback
    var markerStyle: AyahMarkerStyle = .fallback

    /// What a view drawn outside the reader gets — a preview, or a `VerseRow` reused somewhere
    /// that has not resolved a paper. The app's own colours at the app's own size, in the
    /// default face.
    static let fallback = ReadingStyle(
        palette: Theme.fallback.reading(.system),
        typography: .fallback
    )

    /// The leading between two wrapped lines of verse at a size that is already final: the face's
    /// floor, and the reader's own addition on top of it.
    func lineSpacing(atScaledSize size: Double) -> Double {
        font.lineSpacing(for: size) + typography.lineSpacing
    }
}
