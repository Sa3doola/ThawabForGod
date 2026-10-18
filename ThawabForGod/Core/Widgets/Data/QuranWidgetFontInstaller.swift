//
//  QuranWidgetFontInstaller.swift
//  ThawabForGod
//

import Foundation

/// Copies KFGQPC Hafs into the App Group container (`QuranWidgetFont.containerFileURL`), which the
/// widget registers at draw time. The font may be redistributed unmodified.
nonisolated struct QuranWidgetFontInstaller: QuranWidgetFontInstalling {
    init() {}

    @concurrent func install(from source: URL) async -> Bool {
        guard let target = QuranWidgetFont.containerFileURL else { return false }
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
            try manager.copyItem(at: source, to: target)
            return true
        } catch {
            return false
        }
    }
}
