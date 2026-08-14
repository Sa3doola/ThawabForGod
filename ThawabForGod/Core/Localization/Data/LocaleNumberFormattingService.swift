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
    private let integerFormatters: [NumberSystem: NumberFormatter]

    init() {
        var integers: [NumberSystem: NumberFormatter] = [:]

        for system in NumberSystem.allCases {
            let integer = NumberFormatter()
            integer.locale = Locale(identifier: system.localeIdentifier)
            integer.numberStyle = .decimal
            integer.maximumFractionDigits = 0
            integers[system] = integer
        }

        self.integerFormatters = integers
    }

    func string(from value: Int, system: NumberSystem) -> String {
        guard let formatter = integerFormatters[system],
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
