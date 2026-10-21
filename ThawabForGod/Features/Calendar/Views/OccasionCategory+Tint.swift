//
//  OccasionCategory+Tint.swift
//  ThawabForGod
//

import SwiftUI

extension OccasionCategory {

    /// A category's tint, taken from the palette's own tokens — never a literal colour. `success`
    /// is fixed across the four accents, which is what keeps Eid the same colour in all of them.
    func tint(in theme: Theme) -> Color {
        switch self {
        case .eid: theme.success
        case .fasting: theme.accent
        case .night: theme.primary
        case .season: theme.warning
        case .historical: theme.textSecondary
        }
    }
}
