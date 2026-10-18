//
//  QuranWidgetProvider.swift
//  NoorWidgets
//

import CoreText
import Foundation
import WidgetKit

/// One moment of a Quran widget: the stored snapshot (nil until the app has written one), the
/// presentation choices, and whether the Hafs face is registered in this process.
nonisolated struct QuranWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: QuranWidgetSnapshot?
    let style: NextPrayerSnapshot.Style
    let hasHafs: Bool
}

/// Registers the Hafs face the app copied into the App Group container. Idempotent.
nonisolated enum QuranWidgetFontRegistration {

    /// True when `QuranWidgetFont.postScriptName` can be drawn in this process.
    static func register() -> Bool {
        if isKnown { return true }
        guard let url = QuranWidgetFont.containerFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return false }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        // Registration can report an error for an already-registered file, so ask the font
        // system whether the name resolves rather than trusting the return value.
        return isKnown
    }

    private static var isKnown: Bool {
        let font = CTFontCreateWithName(QuranWidgetFont.postScriptName as CFString, 12, nil)
        return CTFontCopyPostScriptName(font) as String == QuranWidgetFont.postScriptName
    }
}

/// Shared timeline construction for the two Quran kinds.
private nonisolated enum QuranWidgetTimeline {

    static func entry(at date: Date) -> QuranWidgetEntry {
        let store = UserDefaultsSettingsStore(defaults: SharedDefaults.store)
        return QuranWidgetEntry(
            date: date,
            snapshot: QuranWidgetSnapshot.load(from: store),
            style: .current(from: store),
            hasHafs: QuranWidgetFontRegistration.register()
        )
    }

    static func nextMidnight(after now: Date) -> Date {
        let calendar = DailyAyahRule.calendar
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 60 * 60)
    }
}

/// Continue Reading: one entry now; the app reloads this kind on each settled position.
struct ContinueReadingProvider: TimelineProvider {

    init() {}

    func placeholder(in context: Context) -> QuranWidgetEntry {
        QuranWidgetTimeline.entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuranWidgetEntry) -> Void) {
        completion(QuranWidgetTimeline.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuranWidgetEntry>) -> Void) {
        let now = Date()
        completion(Timeline(
            entries: [QuranWidgetTimeline.entry(at: now)],
            policy: .after(QuranWidgetTimeline.nextMidnight(after: now))
        ))
    }
}

/// Ayah of the Day: an entry now and one at the next midnight, so the ayah turns over unprompted.
struct AyahOfTheDayProvider: TimelineProvider {

    init() {}

    func placeholder(in context: Context) -> QuranWidgetEntry {
        QuranWidgetTimeline.entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuranWidgetEntry) -> Void) {
        completion(QuranWidgetTimeline.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuranWidgetEntry>) -> Void) {
        let now = Date()
        let midnight = QuranWidgetTimeline.nextMidnight(after: now)
        completion(Timeline(
            entries: [QuranWidgetTimeline.entry(at: now), QuranWidgetTimeline.entry(at: midnight)],
            policy: .after(midnight)
        ))
    }
}
