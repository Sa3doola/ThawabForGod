//
//  QuranPageFonts.swift
//  ThawabForGod
//

import Foundation

/// Where the Madani V2 page fonts live in the bundle: one face per printed page, 604 of them.
///
/// **Named once, here**, because two things must agree on it and nothing else checks that they
/// do. `FontRegistrar` skips this folder at launch — registering 604 faces before the first frame
/// would cost the launch and most of the memory budget, for pages the reader will mostly never
/// open — and the page renderer registers a window of them around the page on screen (Mushaf's
/// `FontPackStore`, ported in M4). The folder is a reference added by
/// `Tools/add_quran_data_phase.rb`, filled from QUL's downloads by `Tools/QuranBuilder --profile qul`,
/// and empty but for a README in a public clone.
///
/// `MushafStyle.madaniV2` reads it for its `PageFontPack`, so the style, the registrar and the
/// page-font store cannot name three different folders.
nonisolated enum QuranPageFonts {
    /// The folder's name, which is also its name inside the app bundle.
    static let folderName = "madaniV2"
}
