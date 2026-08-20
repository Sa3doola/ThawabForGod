//
//  RecentActivityRecord.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// The stored form of `RecentActivity`.
///
/// `kindRaw` is unique because the kind *is* the identity — one row per kind, replaced rather
/// than appended. `@Attribute(.unique)` is per-property, which is exactly what is needed here and
/// the reason this can express in the schema what `QuranBookmarkRecord` has to enforce in its
/// repository: that one keys on two columns, and `#Unique` over several is iOS 18.
///
/// A raw `String` rather than the enum: SwiftData can persist a `Codable` enum, but a raw value it
/// no longer recognises then fails the whole fetch. Storing the string and mapping on the way out
/// lets an unknown kind be dropped, which is the same forward-compatibility rule `HomeLayout`
/// follows for the same reason.
@Model
final class RecentActivityRecord {
    @Attribute(.unique) var kindRaw: String
    var subject: String
    var progressValue: Int
    var progressTotal: Int
    var occurredAt: Date

    init(
        kindRaw: String,
        subject: String,
        progressValue: Int,
        progressTotal: Int,
        occurredAt: Date
    ) {
        self.kindRaw = kindRaw
        self.subject = subject
        self.progressValue = progressValue
        self.progressTotal = progressTotal
        self.occurredAt = occurredAt
    }

    convenience init(_ activity: RecentActivity) {
        self.init(
            kindRaw: activity.kind.rawValue,
            subject: activity.subject,
            progressValue: activity.progressValue,
            progressTotal: activity.progressTotal,
            occurredAt: activity.occurredAt
        )
    }

    /// `nil` for a kind this build no longer has — dropped on the way out rather than trapping.
    var domainValue: RecentActivity? {
        guard let kind = ActivityKind(rawValue: kindRaw) else { return nil }

        return RecentActivity(
            kind: kind,
            subject: subject,
            progressValue: progressValue,
            progressTotal: progressTotal,
            occurredAt: occurredAt
        )
    }

    func apply(_ activity: RecentActivity) {
        subject = activity.subject
        progressValue = activity.progressValue
        progressTotal = activity.progressTotal
        occurredAt = activity.occurredAt
    }
}
