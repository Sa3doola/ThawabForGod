//
//  MoonLightingTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

struct MoonLightingTests {

    private func expectDirection(
        _ degrees: Double,
        _ hemisphere: MoonHemisphere,
        _ x: Double, _ z: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let sun = MoonLighting.sunDirection(elongationDegrees: degrees, hemisphere: hemisphere)
        #expect(abs(sun.x - x) < 1e-9, "x at \(degrees)°", sourceLocation: sourceLocation)
        #expect(sun.y == 0, "y at \(degrees)°", sourceLocation: sourceLocation)
        #expect(abs(sun.z - z) < 1e-9, "z at \(degrees)°", sourceLocation: sourceLocation)
    }

    @Test func northernQuartersPutTheSunWherePhaseSays() {
        expectDirection(0, .northern, 0, -1)     // new: behind the Moon
        expectDirection(90, .northern, 1, 0)     // first quarter: from the right
        expectDirection(180, .northern, 0, 1)    // full: from the camera
        expectDirection(270, .northern, -1, 0)   // last quarter: from the left
    }

    @Test func southernViewIsTheSameMoonTurnedOver() {
        expectDirection(0, .southern, 0, -1)
        expectDirection(90, .southern, -1, 0)
        expectDirection(180, .southern, 0, 1)
        expectDirection(270, .southern, 1, 0)
    }

    @Test func theDirectionIsAlwaysAUnitVector() {
        for degrees in stride(from: 0.0, through: 360, by: 17.5) {
            for hemisphere in [MoonHemisphere.northern, .southern] {
                let sun = MoonLighting.sunDirection(elongationDegrees: degrees, hemisphere: hemisphere)
                #expect(abs(sun.x * sun.x + sun.y * sun.y + sun.z * sun.z - 1) < 1e-9)
            }
        }
    }

    @Test func aWaxingMoonIsLitOnTheSideMoonViewLightsIt() {
        // MoonView lights the right for a waxing northern Moon: waxing is elongation 0–180°.
        #expect(MoonLighting.sunDirection(elongationDegrees: 45, hemisphere: .northern).x > 0)
        #expect(MoonLighting.sunDirection(elongationDegrees: 315, hemisphere: .northern).x < 0)
        #expect(MoonLighting.sunDirection(elongationDegrees: 45, hemisphere: .southern).x < 0)
    }

    @Test func onlyTheSouthIsRolled() {
        #expect(MoonLighting.viewRollDegrees(hemisphere: .northern) == 0)
        #expect(MoonLighting.viewRollDegrees(hemisphere: .southern) == 180)
    }

    @Test func earthshineMatchesTheDrawnMoon() {
        #expect((0.06...0.10).contains(MoonLighting.earthshine))
    }
}

@MainActor
struct MoonSceneTests {

    @Test func theLightTravelsFromTheSunTowardTheMoonForEveryPhase() {
        for hemisphere in [MoonHemisphere.northern, .southern] {
            for degrees in [0.0, 45, 90, 135, 180, 225, 270, 315] {
                let moon = MoonScene(elongationDegrees: degrees, hemisphere: hemisphere)
                let sun = MoonLighting.sunDirection(elongationDegrees: degrees, hemisphere: hemisphere)
                let travel = moon.lightTravelDirection

                #expect(abs(travel.x + sun.x) < 1e-5, "x at \(degrees)° \(hemisphere)")
                #expect(abs(travel.y + sun.y) < 1e-5, "y at \(degrees)° \(hemisphere)")
                #expect(abs(travel.z + sun.z) < 1e-5, "z at \(degrees)° \(hemisphere)")
            }
        }
    }

    @Test func theSceneHasEarthshineAndTheMoonTexture() {
        let moon = MoonScene(elongationDegrees: 90, hemisphere: .northern)

        #expect(moon.hasTexture)
        #expect(abs(moon.ambientIntensity - 1000 * MoonLighting.earthshine) < 1e-6)
    }

    @Test func aNewMoonIsLitFromBehindAndAFullMoonFromTheCamera() {
        #expect(MoonScene(elongationDegrees: 0, hemisphere: .northern).lightTravelDirection.z > 0.99)
        #expect(MoonScene(elongationDegrees: 180, hemisphere: .northern).lightTravelDirection.z < -0.99)
    }
}
