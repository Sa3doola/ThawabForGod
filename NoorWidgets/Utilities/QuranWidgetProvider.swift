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
        return (QuranWidgetSnapshot.load(from: store), .current(from: store), QuranWidgetFontRegistration.registerOnce())
    }

    /// The gallery and the placeholder: the bundled sample, and nothing else. No App Group read, no
    /// font registration, no decode of the stored list — a preview that waits on any of those is a
    /// grey bar (BUGS.md B16).
    static func previewEntry() -> QuranWidgetEntry {
        QuranWidgetTimeline.previewEntry(now: Date(), sample: QuranWidgetSnapshot.sample(), style: .preview())
    }

    /// A snapshot request: instant in the gallery, the real entry on a Home Screen.
    static func snapshotEntry(isPreview: Bool, trimmedTo days: Int?) -> QuranWidgetEntry {
        if isPreview { return previewEntry() }
        let inputs = load()
        let held = days.map { inputs.snapshot?.trimmed(from: Date(), days: $0) } ?? inputs.snapshot?.withoutDailyList()
        return QuranWidgetEntry(date: Date(), snapshot: held, style: inputs.style, hasHafs: inputs.hasHafs)
    }
}

/// Continue Reading: one entry now; the app reloads this kind on each settled position.
struct ContinueReadingProvider: TimelineProvider {

    init() {}

    func placeholder(in context: Context) -> QuranWidgetEntry {
        QuranWidgetInputs.previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (QuranWidgetEntry) -> Void) {
        completion(QuranWidgetInputs.snapshotEntry(isPreview: context.isPreview, trimmedTo: nil))
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
        QuranWidgetInputs.previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (QuranWidgetEntry) -> Void) {
        completion(QuranWidgetInputs.snapshotEntry(isPreview: context.isPreview, trimmedTo: 1))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuranWidgetEntry>) -> Void) {
        let inputs = QuranWidgetInputs.load()
        let result = QuranWidgetTimeline.ayahOfTheDay(
            now: Date(), snapshot: inputs.snapshot, style: inputs.style, hasHafs: inputs.hasHafs)
        completion(Timeline(entries: result.entries, policy: .after(result.reloadAfter)))
    }
}
