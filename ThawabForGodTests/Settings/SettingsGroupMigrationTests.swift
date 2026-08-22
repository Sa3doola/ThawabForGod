//
//  SettingsGroupMigrationTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Moving an existing install's preferences into the App Group.
///
/// `.serialized` because every test here works against real `UserDefaults` suites — the type
/// under test takes two of them, and there is no protocol between it and Foundation, deliberately:
/// what is being tested *is* the interaction with `UserDefaults`, and a fake in the middle would
/// only assert that the fake behaves the way the fake was written.
///
/// Each test opens a suite named after itself and removes it afterwards, so nothing leaks into
/// the test host's own defaults or into the next test.
@Suite(.serialized)
struct SettingsGroupMigrationTests {

    /// A pair of throwaway suites, torn down by `remove()`.
    private struct Suites: ~Copyable {
        let source: UserDefaults
        let destination: UserDefaults
        private let names: (String, String)

        init(_ label: String) {
            names = ("test.migration.\(label).source", "test.migration.\(label).destination")
            source = UserDefaults(suiteName: names.0)!
            destination = UserDefaults(suiteName: names.1)!
            source.removePersistentDomain(forName: names.0)
            destination.removePersistentDomain(forName: names.1)
        }

        func remove() {
            source.removePersistentDomain(forName: names.0)
            destination.removePersistentDomain(forName: names.1)
        }
    }

    @Test func itCopiesWhatTheUserHadChosen() {
        let suites = Suites("copies")
        defer { suites.remove() }

        suites.source.set("emerald", forKey: SettingsKey.accentPalette.rawValue)
        suites.source.set(true, forKey: SettingsKey.onboardingCompleted.rawValue)
        suites.source.set(51.5074, forKey: SettingsKey.latitude.rawValue)

        let copied = SettingsGroupMigration.run(from: suites.source, to: suites.destination)

        #expect(Set(copied) == Set([.accentPalette, .onboardingCompleted, .latitude]))
        #expect(suites.destination.string(forKey: SettingsKey.accentPalette.rawValue) == "emerald")
        #expect(suites.destination.object(forKey: SettingsKey.onboardingCompleted.rawValue) as? Bool == true)
        #expect(suites.destination.object(forKey: SettingsKey.latitude.rawValue) as? Double == 51.5074)
    }

    /// The project's standing rule about preferences, carried through the migration: an unset key
    /// means the user has never opinionated about that choice. Writing today's default into the
    /// group would convert "no preference" into one that outranks the device forever — which is
    /// exactly the bug onboarding was once shipped with and had to be repaired.
    @Test func itInventsNothingTheUserNeverChose() {
        let suites = Suites("invents-nothing")
        defer { suites.remove() }

        suites.source.set("dark", forKey: SettingsKey.appearance.rawValue)

        SettingsGroupMigration.run(from: suites.source, to: suites.destination)

        for key in SettingsKey.allCases where key != .appearance {
            #expect(
                suites.destination.object(forKey: key.rawValue) == nil,
                "\(key) was written despite never having been set"
            )
        }
    }

    /// The group is the newer store by definition, so anything already in it wins.
    @Test func itNeverOverwritesWhatTheGroupAlreadyHolds() {
        let suites = Suites("no-overwrite")
        defer { suites.remove() }

        suites.source.set("amber", forKey: SettingsKey.accentPalette.rawValue)
        suites.destination.set("sapphire", forKey: SettingsKey.accentPalette.rawValue)

        let copied = SettingsGroupMigration.run(from: suites.source, to: suites.destination)

        #expect(copied.isEmpty)
        #expect(suites.destination.string(forKey: SettingsKey.accentPalette.rawValue) == "sapphire")
    }

    /// Runs once. A second pass must not resurrect a key the user has since cleared — which is
    /// what "reset" writes, and what would otherwise come back on the next launch.
    @Test func itRunsOnlyOnce() {
        let suites = Suites("once")
        defer { suites.remove() }

        suites.source.set("karachi", forKey: SettingsKey.calculationMethod.rawValue)

        #expect(SettingsGroupMigration.run(from: suites.source, to: suites.destination) == [.calculationMethod])

        suites.destination.removeObject(forKey: SettingsKey.calculationMethod.rawValue)
        let second = SettingsGroupMigration.run(from: suites.source, to: suites.destination)

        #expect(second.isEmpty)
        #expect(suites.destination.object(forKey: SettingsKey.calculationMethod.rawValue) == nil)
    }

    /// The case that would be silent and permanent: with no App Group entitlement,
    /// `SharedDefaults.store` falls back to `.standard`, so source and destination are the same
    /// object. Marking the migration done there would stamp the *wrong* store, and the real
    /// migration would never run once the entitlement arrived.
    @Test func itDoesNothingWhenThereIsNoSeparateGroupToMoveTo() {
        let suites = Suites("same-store")
        defer { suites.remove() }

        suites.source.set("amber", forKey: SettingsKey.accentPalette.rawValue)

        #expect(SettingsGroupMigration.run(from: suites.source, to: suites.source).isEmpty)

        // And having declined, it still runs properly against a real group afterwards.
        #expect(SettingsGroupMigration.run(from: suites.source, to: suites.destination) == [.accentPalette])
    }
}
