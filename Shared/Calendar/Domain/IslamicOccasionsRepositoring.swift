//
//  IslamicOccasionsRepositoring.swift
//  ThawabForGod
//

import Foundation

nonisolated protocol IslamicOccasionsRepositoring: Sendable {
    /// Every occasion, in the file's order.
    func occasions() -> [IslamicOccasion]
}
