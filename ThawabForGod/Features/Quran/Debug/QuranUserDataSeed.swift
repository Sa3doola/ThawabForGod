//
//  QuranUserDataSeed.swift
//  ThawabForGod
//

#if DEBUG
import Foundation
import os

extension QuranUserDataStore {
    /// `-quranResetUserData YES` empties the marks; `-quranSeedUserData YES` then adds five
    /// bookmarks, three notes and six highlights through the public setters, and logs the counts
    /// once the write chain has drained. The counts are logged on every DEBUG launch, flags or not, so
    /// a relaunch with no flags shows what was actually stored. DEBUG only, and developer-facing.
    func applyDebugLaunchOptions(_ options: QuranLaunchOptions) {
        if options.resetsUserData { removeAllMarksForDebug() }
        if options.seedsUserData { seed() }

        Task { [self] in
            await flush()
            Logger(subsystem: "ThawabForGod", category: "QuranUserData").notice(
                "quranUserData: \(self.bookmarks.count) bookmarks, \(self.notes.count) notes, \(self.highlights.count) highlights"
            )
        }
    }

    private func seed() {
        for (surah, verse) in [(1, 1), (2, 255), (2, 3), (36, 1), (18, 10)] {
            setBookmarked(true, ayah: VerseReference(surah: surah, verse: verse))
        }
        setNote("Ayat al-Kursi: read after every prayer.", for: VerseReference(surah: 2, verse: 255))
        setNote("Three signs of the God-fearing: belief in the unseen, prayer, spending.", for: VerseReference(surah: 2, verse: 3))
        setNote("The heart of the Quran.", for: VerseReference(surah: 36, verse: 1))
        let colors: [(Int, Int, HighlightColor)] = [(2, 2, .yellow), (2, 3, .green), (2, 4, .blue), (2, 5, .pink), (2, 255, .yellow), (1, 5, .green)]
        for (surah, verse, color) in colors {
            setHighlight(color, for: VerseReference(surah: surah, verse: verse))
        }
    }
}
#endif
