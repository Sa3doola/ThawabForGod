//
//  AstronomicalMoonCalculator.swift
//  ThawabForGod
//

import Foundation

/// The Moon's phase and distance from Jean Meeus, *Astronomical Algorithms* (2nd ed.),
/// chapters 47 and 48, in their short forms.
///
/// Accurate to a fraction of a degree of elongation — tens of minutes on an event time and a
/// percent or so on illumination — which is what a calendar screen needs and nothing more. No
/// network and no ephemeris file.
///
/// The elongation is the *true* one, `D` plus the periodic terms of the phase-angle series
/// (i = 180° − elongation), because the mean `D` alone is off by up to ~6° near the quarters and
/// the new/full moon times found from it would be hours out.
nonisolated struct AstronomicalMoonCalculator: MoonPhaseCalculating {

    /// A synodic month, for stepping; the search never relies on it being exact.
    private static let meanSynodicDays = 29.530588

    func info(at date: Date) -> MoonInfo {
        let angles = Self.angles(at: date)
        let elongation = Self.elongation(angles)
        return MoonInfo(
            date: date,
            phase: MoonPhase(elongationDegrees: elongation),
            illuminatedFraction: (1 - cos(Self.radians(elongation))) / 2,
            elongationDegrees: elongation,
            isWaxing: elongation < 180,
            ageInDays: date.timeIntervalSince(lastNewMoon(onOrBefore: date)) / 86_400,
            distanceKm: Self.distance(angles)
        )
    }

    /// Estimates the new moon from the elongation (age ≈ elongation/360 of a mean month), then
    /// bisects a four-day window either side of the estimate. The Moon's speed varies by about
    /// ±10%, so the true event is always inside it, and the cost is a handful of evaluations
    /// rather than a scan back through the month.
    func lastNewMoon(onOrBefore date: Date) -> Date {
        let elongation = Self.elongation(Self.angles(at: date))
        let estimate = date.addingTimeInterval(-elongation / 360 * Self.meanSynodicDays * 86_400)
        return Self.bisect(
            from: estimate.addingTimeInterval(-4 * 86_400),
            to: estimate.addingTimeInterval(4 * 86_400),
            crossing: 0
        )
    }

    func nextNewMoon(after date: Date) -> Date { nextCrossing(of: 0, after: date) }
    func nextFullMoon(after date: Date) -> Date { nextCrossing(of: 180, after: date) }

    // MARK: Search

    /// Elongation as a signed offset from the target is what has a sign change to find, so the
    /// search works on `wrap(elongation − target)` in −180…180: negative before the event,
    /// positive after, jumping only at the opposite side of the orbit.
    private func nextCrossing(of target: Double, after date: Date) -> Date {
        var lower = date
        for _ in 0..<(31 * 24) {
            let upper = lower.addingTimeInterval(3600)
            let a = Self.signed(Self.elongation(Self.angles(at: lower)), target)
            let b = Self.signed(Self.elongation(Self.angles(at: upper)), target)
            if a < 0, b >= 0 { return Self.bisect(from: lower, to: upper, crossing: target) }
            lower = upper
        }
        return lower
    }

    private static func bisect(from lower: Date, to upper: Date, crossing target: Double) -> Date {
        var low = lower, high = upper
        while high.timeIntervalSince(low) > 30 {
            let mid = Date(timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2)
            if signed(elongation(angles(at: mid)), target) < 0 { low = mid } else { high = mid }
        }
        return Date(timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2)
    }

    private static func signed(_ elongation: Double, _ target: Double) -> Double {
        var delta = (elongation - target).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    // MARK: Meeus

    private struct Angles {
        let d, m, mPrime: Double   // radians
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func angles(at date: Date) -> Angles {
        let jd = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (jd - 2_451_545) / 36_525
        let d = 297.8501921 + 445_267.1114034 * t - 0.0018819 * t * t + t * t * t / 545_868
        let m = 357.5291092 + 35_999.0502909 * t - 0.0001536 * t * t
        let mPrime = 134.9633964 + 477_198.8675055 * t + 0.0087414 * t * t + t * t * t / 69_699
        return Angles(d: radians(d), m: radians(m), mPrime: radians(mPrime))
    }

    /// Degrees, 0..<360.
    private static func elongation(_ a: Angles) -> Double {
        // 180° − i, with i from chapter 48.
        let correction = 6.289 * sin(a.mPrime)
            - 2.100 * sin(a.m)
            + 1.274 * sin(2 * a.d - a.mPrime)
            + 0.658 * sin(2 * a.d)
            + 0.214 * sin(2 * a.mPrime)
            + 0.110 * sin(a.d)
        let value = (a.d * 180 / .pi + correction).truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// Kilometres, from the principal terms of Table 47.A (without the eccentricity factor),
    /// rounded to the nearest hundred.
    private static func distance(_ a: Angles) -> Double {
        let d = a.d, m = a.m, p = a.mPrime
        let km = 385_000.56
            - 20_905.355 * cos(p)
            - 3_699.111 * cos(2 * d - p)
            - 2_955.968 * cos(2 * d)
            - 569.925 * cos(2 * p)
            + 246.158 * cos(2 * d - 2 * p)
            - 204.586 * cos(2 * d - m)
            - 170.733 * cos(2 * d + p)
            - 152.138 * cos(2 * d - m - p)
            - 129.620 * cos(m - p)
            + 108.743 * cos(d)
            + 104.755 * cos(m + p)
            + 48.888 * cos(m)
        return (km / 100).rounded() * 100
    }
}
