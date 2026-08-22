//
//  SettingsGroupMigration.swift
//  ThawabForGod
//

import Foundation

/// Moves an existing install's preferences into the shared suite, once.
///
/// Everyone who had the app before the widget existed has their settings in
/// `UserDefaults.standard`, which the widget cannot see. Without this they would open the new
/// build to a Home screen they never arranged, in a colour they did not choose, with prayer
/// times computed by the default method.
///
/// **It copies only keys that already exist.** That is the project's standing rule about
/// preferences held here rather than assumed: an unset key means the user has never opinionated
/// about that choice, and writing today's default into the group would convert "no preference"
/// into a preference that outranks the device forever. So a key absent from `standard` stays
/// absent from the group.
///
/// It also never overwrites. If the group already holds a value — because a later build wrote
/// one, or because this ran before — the group wins, since it is the newer of the two by
/// definition.
///
/// The marker is written straight into the group's defaults rather than added to `SettingsKey`.
/// `SettingsKey` is "every user preference the app persists", and whether a migration has run is
/// not one; putting it there would put a row in a list that Settings screens iterate.
nonisolated enum SettingsGroupMigration {

    private static let markerKey = "settings.migratedToAppGroup"

    /// Runs the copy if it has not run before.
    ///
    /// - Parameters:
    ///   - source: where an older build wrote. `UserDefaults.standard` in the app.
    ///   - destination: the shared suite.
    /// - Returns: the keys that were copied, which is what makes this testable without
    ///   inspecting either store afterwards. Empty when there was nothing to do.
    @discardableResult
    static func run(
        from source: UserDefaults = .standard,
        to destination: UserDefaults = SharedDefaults.store
    ) -> [SettingsKey] {
        // Nothing to do when the two are the same object — which is exactly what happens when
        // the App Group is unavailable and `SharedDefaults.store` fell back to `.standard`.
        // Copying a store onto itself would mark the migration done against a suite that is not
        // the shared one, so the real migration would never run once the entitlement landed.
        guard source !== destination else { return [] }
        guard !destination.bool(forKey: markerKey) else { return [] }

        var copied: [SettingsKey] = []

        for key in SettingsKey.allCases {
            guard let value = source.object(forKey: key.rawValue) else { continue }
            guard destination.object(forKey: key.rawValue) == nil else { continue }

            destination.set(value, forKey: key.rawValue)
            copied.append(key)
        }

        destination.set(true, forKey: markerKey)

        return copied
    }

    /// Forgets that the migration ran. Tests only — there is no reason for the app to call it.
    static func reset(in destination: UserDefaults) {
        destination.removeObject(forKey: markerKey)
    }
}
