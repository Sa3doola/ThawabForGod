//
//  QuranWidgetFontInstaller.swift
//  ThawabForGod
//

import Foundation

/// Copies KFGQPC Hafs and Amiri Quran (both redistributable unmodified) into the App Group
/// container's font folder (`QuranWidgetFont.containerFolderURL`), which the widget registers at
/// draw time.
nonisolated struct QuranWidgetFontInstaller: QuranWidgetFontInstalling {
    init() {}

    @concurrent func install(from sources: [URL]) async -> Bool {
        guard !sources.isEmpty, let folder = QuranWidgetFont.containerFolderURL else { return false }
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            for source in sources {
                let target = folder.appendingPathComponent(source.lastPathComponent)
                if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
                try manager.copyItem(at: source, to: target)
            }
            return true
        } catch {
            return false
        }
    }
}
