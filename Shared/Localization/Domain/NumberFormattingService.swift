//
//  NumberFormattingService.swift
//  ThawabForGod
//

import Foundation

/// Renders numbers in the digits the user picked. Every number the app displays — counts,
/// prayer times, page numbers — goes through this rather than string interpolation.
nonisolated protocol NumberFormattingService: Sendable {
    /// - Parameter grouped: whether to insert the locale's thousands separator. Pass `false`
    ///   for a number that names something rather than counts it — a Hijri year is 1448, not
    ///   1,448, and no locale groups a year.
    func string(from value: Int, grouped: Bool, system: NumberSystem) -> String
    func string(from value: Double, fractionDigits: Int, system: NumberSystem) -> String
}

extension NumberFormattingService {
    /// Grouped, which is right for the common case: counts and quantities.
    func string(from value: Int, system: NumberSystem) -> String {
        string(from: value, grouped: true, system: system)
    }
}
