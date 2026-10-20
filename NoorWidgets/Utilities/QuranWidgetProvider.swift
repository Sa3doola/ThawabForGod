//
//  QuranWidgetProvider.swift
//  NoorWidgets
//

import Foundation
import WidgetKit

// `QuranWidgetEntry` already has the `date` the protocol asks for.
extension QuranWidgetEntry: TimelineEntry {}

/// Reads what the two Quran kinds share: the snapshot, the style and the font state.
private nonisolated enum QuranWidgetInputs {
    static func load() -> (snapshot: QuranWidgetSnapshot?, style: NextPrayerSnapshot.Style, hasHafs: Bool) {
        let store = UserDefaultsSettingsStore(defaults: SharedDefaults.store)
        return (QuranWidgetSnapshot.load(from: store), .current(from: store), QuranWidgetFontRegistration.register())
    }

    static func entry(at date: Date) -> QuranWidgetEntry {
        let inputs = load()
        return QuranWidgetEntry(date: date, snapshot: inputs.snapshot, style: inputs.style, hasHafs: inputs.hasHafs)
    }
}

/// Continue Reading: one entry now; the app reloads this kind on each settled position.
struct ContinueReadingProvider: TimelineProvider {

    init() {}

    func placeholder(in context: Context) -> QuranWidgetEntry {
        QuranWidgetInputs.entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuranWidgetEntry) -> Void) {
        completion(QuranWidgetInputs.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuranWidgetEntry>) -> Void) {
        let inputs = QuranWidgetInputs.load()
        let result = QuranWidgetTimeline.continueReading(
            now: Date(), snapshot: inputs.snapshot, style: inputs.style, hasHafs: inputs.hasHafs)
        completion(Timeline(entries: result.entries, policy: .after(result.reloadAfter)))
    }
}

/// Ayah of the Day: an entry now and one at each of the next seven midnights.
struct AyahOfTheDayProvider: TimelineProvider {

    init() {}

    func placeholder(in context: Context) -> QuranWidgetEntry {
        QuranWidgetInputs.entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuranWidgetEntry) -> Void) {
        completion(QuranWidgetInputs.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuranWidgetEntry>) -> Void) {
        let inputs = QuranWidgetInputs.load()
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: Date(), snapshot: inputs.snapshot, style: inputs.style, hasHafs: inputs.hasHafs)
        completion(Timeline(entries: result.entries, policy: .after(result.reloadAfter)))
    }
}
