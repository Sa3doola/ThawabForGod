//
//  PrayerCompletionRecord.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// One day's marked prayers.
///
/// `day` is unique because a day is the row — see `PrayerRecord` for why the unit is a day rather
/// than a prayer.
///
/// The prayers are stored as their raw values rather than as an encoded `Set<Prayer>`: a raw value
/// this build no longer knows is then dropped on the way out instead of failing the fetch, which
/// is the same forward-compatibility rule `HomeLayout` and `RecentActivityRecord` follow.
@Model
final class PrayerCompletionRecord {
    @Attribute(.unique) var day: Date
    var completedRaw: [String]

    init(day: Date, completedRaw: [String]) {
        self.day = day
        self.completedRaw = completedRaw
    }

    convenience init(_ record: PrayerRecord) {
        self.init(
            day: record.day,
            completedRaw: record.completed.map(\.rawValue).sorted()
        )
    }

    var domainValue: PrayerRecord {
        PrayerRecord(day: day, completed: Set(completedRaw.compactMap(Prayer.init(rawValue:))))
    }

    func apply(_ record: PrayerRecord) {
        completedRaw = record.completed.map(\.rawValue).sorted()
    }
}
