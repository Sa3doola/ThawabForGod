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

    /// Developer-facing label for the design-system gallery only.
    var developerLabel: String {
        rawValue.capitalized
    }
}
