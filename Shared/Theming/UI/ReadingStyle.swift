//
//  ReadingStyle.swift
//  ThawabForGod
//

import SwiftUI

/// What a passage of scripture is drawn with, beyond the app's own theme.
///
/// Passed through the environment rather than down through initialisers because the verse a
/// reader looks at is several views below the screen that resolves their choices, and the sheet
/// that edits them is presented from the top — so the value has to reach a leaf without every view
/// in between naming it.
///
/// Only the face. The page's colours are `\.readingPalette`, a separate entry so a view that
/// reads one is not invalidated by a change to the other: the face changes in separated mode
/// only, the theme on every page.
nonisolated struct ReadingStyle: Equatable, Sendable {
    var font: ReaderFont = .fallback

    /// What a view drawn outside the reader gets — a preview, a widget, the adhkar: the default
    /// face.
    static let fallback = ReadingStyle()
}
