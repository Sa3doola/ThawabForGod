//
//  SharedDefaults.swift
//  ThawabForGod
//

import Foundation

/// The defaults database the app shares with its extensions.
///
/// A widget runs in its own process and sees its own `UserDefaults.standard`, which is empty.
/// An App Group gives the two a suite they both open, and this is the one place its identifier
/// is written down — it must match the `com.apple.security.application-groups` entitlement on
/// **both** targets exactly.
///
/// One identifier, both platforms. Apple's older guidance had macOS group identifiers carry the
/// Team ID prefix, which would mean two strings and a `#if`; current Xcode accepts a plain
/// `group.` identifier on macOS too, and one string is one thing to keep in step. If the Mac
/// build ever turns out to disagree, the symptom is described below and the fix is a
/// macOS-specific entitlements file, not a change here.
///
/// **`UserDefaults(suiteName:)` does not check the entitlement**, which is worth knowing before
/// debugging anything. It returns `nil` only for a name that is reserved or equal to the bundle
/// identifier — never because the App Group is missing. An unentitled process gets a perfectly
/// usable store that simply nobody else can see. So a broken group does not throw and does not
/// return `nil`: it presents as a widget showing values the app never wrote. The way to check is
/// to write in one process and read in the other, which is what `isReachable` is for.
nonisolated enum SharedDefaults {

    /// The App Group, as declared in both targets' entitlements.
    static let groupIdentifier = "group.com.Sa3dola.ThawabForGod"

    /// The shared suite.
    ///
    /// The fallback is defensive rather than expected: `UserDefaults(suiteName:)` is documented
    /// to fail only on a reserved name, so this cannot happen with the constant above. An app
    /// that trapped here would refuse to launch over something only the widget needs.
    static var store: UserDefaults {
        UserDefaults(suiteName: groupIdentifier) ?? .standard
    }

    /// Whether the two processes can actually see each other's writes.
    ///
    /// A real round trip — write, read back through a freshly opened handle, clean up — because
    /// nothing cheaper is honest: see the note above about `suiteName` returning a usable store
    /// whether or not the entitlement exists. Nothing in the app branches on this; a `false` is a
    /// project-configuration problem to be found during bring-up, not a runtime state to handle.
    static var isReachable: Bool {
        guard let suite = UserDefaults(suiteName: groupIdentifier), suite != .standard else {
            return false
        }

        let probe = "sharedDefaults.probe"
        let value = UUID().uuidString

        suite.set(value, forKey: probe)
        defer { suite.removeObject(forKey: probe) }

        return UserDefaults(suiteName: groupIdentifier)?.string(forKey: probe) == value
    }
}
