//
//  LocaleNumberFormattingService.swift
//  ThawabForGod
//

import Foundation

/// `NumberFormatter`-backed digits, one formatter per numbering system.
///
/// Safety invariant for `@unchecked Sendable`: the formatters are fully configured in `init`
/// and never mutated afterwards. Foundation documents `NumberFormatter` as safe for
/// concurrent *formatting* under that condition. Building them once matters — a tasbih
/// counter formats on every tap.
nonisolated final class LocaleNumberFormattingService: NumberFormattingService, @unchecked Sendable {
    private let groupedFormatters: [NumberSystem: NumberFormatter]

    /// For numbers that name rather than count — years, page numbers — where a thousands
    /// separator is simply wrong.
    private let ungroupedFormatters: [NumberSystem: NumberFormatter]

    init() {
        self.groupedFormatters = Self.integerFormatters(grouped: true)
        self.ungroupedFormatters = Self.integerFormatters(grouped: false)
    }

    private static func integerFormatters(grouped: Bool) -> [NumberSystem: NumberFormatter] {
        var formatters: [NumberSystem: NumberFormatter] = [:]

        for system in NumberSystem.allCases {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: system.localeIdentifier)
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.usesGroupingSeparator = grouped
            formatters[system] = formatter
        }

        return formatters
    }

    func string(from value: Int, grouped: Bool, system: NumberSystem) -> String {
        let formatters = grouped ? groupedFormatters : ungroupedFormatters

        guard let formatter = formatters[system],
              let formatted = formatter.string(from: NSNumber(value: value)) else {
            return String(value)
        }
        return formatted
    }

    func string(from value: Double, fractionDigits: Int, system: NumberSystem) -> String {
        // Built per call: the digit count varies, and mutating a shared formatter would
        // break the invariant above. Decimals are rare compared with integer counts.
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: system.localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
