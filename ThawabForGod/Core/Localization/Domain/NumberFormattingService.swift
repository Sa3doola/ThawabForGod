//
//  NumberFormattingService.swift
//  ThawabForGod
//

import Foundation

/// Renders numbers in the digits the user picked. Every number the app displays — counts,
/// prayer times, page numbers — goes through this rather than string interpolation.
nonisolated protocol NumberFormattingService: Sendable {
    func string(from value: Int, system: NumberSystem) -> String
    func string(from value: Double, fractionDigits: Int, system: NumberSystem) -> String
}
