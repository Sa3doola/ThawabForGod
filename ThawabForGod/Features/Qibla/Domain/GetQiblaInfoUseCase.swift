//
//  GetQiblaInfoUseCase.swift
//  ThawabForGod
//

import Foundation

/// Resolves a position into a bearing and a distance to the Kaaba.
///
/// A protocol so the view model can be tested against a fixed bearing rather than against real
/// spherical trigonometry — the needle maths and the astronomy are separate things and fail in
/// separate ways.
///
/// Synchronous and `nonisolated` for the same reason as `PrayerTimeCalculating`: this is
/// arithmetic over four numbers, and nothing about it needs a thread or an `await`.
nonisolated protocol GetQiblaInfoUseCase: Sendable {
    func qiblaInfo(for coordinates: Coordinates) -> QiblaInfo
}
