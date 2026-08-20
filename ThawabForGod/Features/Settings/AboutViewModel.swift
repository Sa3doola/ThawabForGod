//
//  AboutViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// What the app is, and what it is built from.
@Observable
@MainActor
final class AboutViewModel {
    @ObservationIgnored private let bundle: Bundle

    /// - Parameter bundle: where the version is read from. Injected so a test does not assert
    ///   against whatever the test host happens to be versioned as.
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// The marketing version, with the build behind it — `1.0 (12)`.
    ///
    /// Not routed through the digit formatter: a version is an identifier rather than a quantity,
    /// and `١.٠ (١٢)` would not match what the App Store, a crash report or a bug reporter says.
    var versionText: String {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = bundle.infoDictionary?["CFBundleVersion"] as? String else {
            return version
        }
        return "\(version) (\(build))"
    }

    /// Every bundled data set and dependency, for the attribution screen.
    var sources: [AttributionSource] { AttributionSource.all }
}
