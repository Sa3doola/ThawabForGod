//
//  AccentPalette.swift
//  ThawabForGod
//

import Foundation

/// The accent colours a user can pick in Settings. The selected one overrides `Theme.accent`.
nonisolated enum AccentPalette: String, CaseIterable, Identifiable, Sendable {
    case amber
    case emerald
    case sapphire
    case rose

    static let fallback: AccentPalette = .amber

    var id: String { rawValue }

    /// Name of the colour set in the asset catalog.
    var assetName: String {
        switch self {
        case .amber: "AccentAmber"
        case .emerald: "AccentEmerald"
        case .sapphire: "AccentSapphire"
        case .rose: "AccentRose"
        }
    }

    /// Developer-facing label for the design-system gallery only.
    /// User-facing labels arrive with the string catalog in the localization step.
    var developerLabel: String {
        rawValue.capitalized
    }
}
