//
//  AppearanceOverride.swift
//  ThawabForGod
//

import Foundation

/// Whether the app follows the system appearance or forces light/dark.
nonisolated enum AppearanceOverride: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    static let fallback: AppearanceOverride = .system

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .system: .appearanceSystem
        case .light: .appearanceLight
        case .dark: .appearanceDark
        }
    }
}
