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

    var labelKey: L10nKey {
        switch self {
        case .amber: .accentAmber
        case .emerald: .accentEmerald
        case .sapphire: .accentSapphire
        case .rose: .accentRose
        }
    }
}
