//
//  QuranWidgetFontInstalling.swift
//  ThawabForGod
//

import Foundation

/// Puts the Quran font where the widget extension can read it: a copy in the App Group container.
///
/// A protocol so the publisher is tested without a file system, and `nonisolated` because the copy
/// belongs on no actor.
nonisolated protocol QuranWidgetFontInstalling: Sendable {
    /// Copies `source` to `QuranWidgetFont.containerFileURL`. `true` when the font is there
    /// afterwards; `false` when there is no App Group container or the copy failed.
    func install(from source: URL) async -> Bool
}
