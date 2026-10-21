//
//  OccasionRule.swift
//  ThawabForGod
//

import Foundation

/// When in the Hijri year an occasion falls.
///
/// Months are 1–12 as `HijriMonth` numbers them. Weekdays are `Calendar`'s: 1 is Sunday.
nonisolated enum OccasionRule: Codable, Equatable, Sendable {
    case fixedDay(month: Int, day: Int)
    case dayRange(month: Int, from: Int, to: Int)
    /// The same days of every Hijri month — the White Days.
    case monthlyDays([Int])
    /// The same weekdays all year — Monday and Thursday.
    case weekly(weekdays: [Int])
    /// Specific nights of one month — the odd nights of Ramadan's last ten.
    case oddNights(month: Int, days: [Int])

    var isRecurring: Bool {
        switch self {
        case .monthlyDays, .weekly: true
        case .fixedDay, .dayRange, .oddNights: false
        }
    }

    func matches(month: Int, day: Int, weekday: Int) -> Bool {
        switch self {
        case let .fixedDay(m, d): month == m && day == d
        case let .dayRange(m, from, to): month == m && (from...to).contains(day)
        case let .monthlyDays(days): days.contains(day)
        case let .weekly(weekdays): weekdays.contains(weekday)
        case let .oddNights(m, days): month == m && days.contains(day)
        }
    }

    // MARK: Codable — `{ "type": "dayRange", "month": 1, "from": 9, "to": 10 }`

    private enum CodingKeys: String, CodingKey {
        case type, month, day, from, to, days, weekdays
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "fixedDay":
            self = .fixedDay(month: try c.decode(Int.self, forKey: .month), day: try c.decode(Int.self, forKey: .day))
        case "dayRange":
            self = .dayRange(month: try c.decode(Int.self, forKey: .month),
                             from: try c.decode(Int.self, forKey: .from), to: try c.decode(Int.self, forKey: .to))
        case "monthlyDays":
            self = .monthlyDays(try c.decode([Int].self, forKey: .days))
        case "weekly":
            self = .weekly(weekdays: try c.decode([Int].self, forKey: .weekdays))
        case "oddNights":
            self = .oddNights(month: try c.decode(Int.self, forKey: .month), days: try c.decode([Int].self, forKey: .days))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown rule type \(other)")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .fixedDay(month, day):
            try c.encode("fixedDay", forKey: .type); try c.encode(month, forKey: .month); try c.encode(day, forKey: .day)
        case let .dayRange(month, from, to):
            try c.encode("dayRange", forKey: .type); try c.encode(month, forKey: .month)
            try c.encode(from, forKey: .from); try c.encode(to, forKey: .to)
        case let .monthlyDays(days):
            try c.encode("monthlyDays", forKey: .type); try c.encode(days, forKey: .days)
        case let .weekly(weekdays):
            try c.encode("weekly", forKey: .type); try c.encode(weekdays, forKey: .weekdays)
        case let .oddNights(month, days):
            try c.encode("oddNights", forKey: .type); try c.encode(month, forKey: .month); try c.encode(days, forKey: .days)
        }
    }
}
