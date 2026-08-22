//
//  LastKnownLocationTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The position a process that cannot ask CoreLocation has to work with.
///
/// Two facts kept in two places, and the whole suite is about not letting them collapse into
/// one: what the user *said* in onboarding, and where the app has actually *been*.
struct LastKnownLocationTests {

    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)
    private let cairo = Coordinates(latitude: 30.0444, longitude: 31.2357)

    @Test func nothingIsKnownBeforeAnythingHasHappened() {
        let store = InMemorySettingsStore()

        #expect(store.lastKnownCoordinates == nil)
        #expect(store.bestKnownCoordinates == nil)
    }

    @Test func aRecordedFixIsReadBack() {
        let store = InMemorySettingsStore()

        store.recordLastKnown(london)

        #expect(store.lastKnownCoordinates == london)
    }

    /// The one that matters. Recording a fix must not touch what onboarding captured — that was
    /// a choice, and a choice the user made has to still be there when the cache is wrong.
    @Test func recordingAFixLeavesOnboardingsAnswerAlone() {
        let store = InMemorySettingsStore(doubles: [
            .latitude: cairo.latitude,
            .longitude: cairo.longitude
        ])

        store.recordLastKnown(london)

        #expect(store.storedCoordinates == cairo)
        #expect(store.lastKnownCoordinates == london)
    }

    @Test func theCachePrecedesOnboardingsAnswer() {
        let store = InMemorySettingsStore(doubles: [
            .latitude: cairo.latitude,
            .longitude: cairo.longitude
        ])

        #expect(store.bestKnownCoordinates == cairo)

        store.recordLastKnown(london)

        #expect(store.bestKnownCoordinates == london)
    }

    /// Zero is a perfectly good latitude — the same trap `storedCoordinates` documents, and the
    /// reason both read through `double(for:)` rather than `UserDefaults.double(forKey:)`.
    @Test func theEquatorIsAPlace() {
        let store = InMemorySettingsStore()
        let nullIsland = Coordinates(latitude: 0, longitude: 0)

        store.recordLastKnown(nullIsland)

        #expect(store.lastKnownCoordinates == nullIsland)
        #expect(store.bestKnownCoordinates == nullIsland)
    }

    /// Half a coordinate pair is a point in the Gulf of Guinea, not a position.
    @Test func halfAPairIsNoPair() {
        let store = InMemorySettingsStore(doubles: [.lastKnownLatitude: london.latitude])

        #expect(store.lastKnownCoordinates == nil)
        #expect(store.bestKnownCoordinates == nil)
    }
}
