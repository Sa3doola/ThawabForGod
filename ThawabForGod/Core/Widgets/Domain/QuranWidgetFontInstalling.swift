//
//  QuranWidgetFontInstalling.swift
//  ThawabForGod
//

import Foundation

/// Puts the Quran fonts where the widget extension can read them: copies in the App Group container.
///
/// A protocol so the publisher is tested without a file system, and `nonisolated` because the copy
/// belongs on no actor.
nonisolated protocol QuranWidgetFontInstalling: Sendable {
    /// Copies each file in `sources` into `QuranWidgetFont.containerFolderURL`, keeping its file name.
    /// `true` when every one is there afterwards; `false` when there is no App Group container, no
    /// source, or any copy failed.
    func install(from sources: [URL]) async -> Bool
}
