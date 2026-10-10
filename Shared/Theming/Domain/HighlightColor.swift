//
//  HighlightColor.swift
//  ThawabForGod
//

import Foundation

/// The four colours a reader can mark an ayah with.
///
/// Here, in the design system, rather than with the Quran's user data (M6), because the *shade*
/// each one is drawn in belongs to the page it sits on — a yellow that reads on Paper is too loud
/// on Dark — and `ReadingPalette` has to name them to look them up. The raw values are what the
/// highlight records will store, so they are a contract: rename a case and keep its raw value.
nonisolated enum HighlightColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case yellow, green, blue, pink

    var id: String { rawValue }
}
