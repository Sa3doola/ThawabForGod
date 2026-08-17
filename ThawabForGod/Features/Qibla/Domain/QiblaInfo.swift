//
//  QiblaInfo.swift
//  ThawabForGod
//

import Foundation

/// Everything the Qibla screen knows about a position, resolved once.
///
/// The three values travel together because they are only meaningful together: a bearing
/// without the point it was measured from is not checkable, and a distance without either is
/// trivia. Holding them as one entity is what stops the view model's readout from drifting out
/// of step with its needle.
nonisolated struct QiblaInfo: Equatable, Sendable {
    /// Where the user is.
    let coordinates: Coordinates

    /// Degrees clockwise from **true** north to the Kaaba.
    let direction: Double

    /// Great-circle distance to the Kaaba, in metres.
    let distanceToKaaba: Double
}
