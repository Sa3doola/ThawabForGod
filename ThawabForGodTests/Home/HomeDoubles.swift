//
//  HomeDoubles.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// A place-name resolver that answers with whatever the test prepared, and counts the asking.
///
/// The count is the interesting half: the card must not go looking for a city when the device
/// has no network, and "did not ask" is the only way to observe that.
///
/// Safety invariant for `@unchecked Sendable`: the count is only ever touched under `lock`, and
/// `name` is immutable. The protocol is `nonisolated`, so no actor could witness it.
nonisolated final class StubPlaceNameResolver: PlaceNameResolving, @unchecked Sendable {
    private let lock = NSLock()
    private let name: String?
    private let isSlow: Bool
    private var asks = 0

    /// - Parameter isSlow: waits long enough that nothing else in a test could plausibly be
    ///   waiting on it. Cancellable, so a cancelled screen still tears the stub down promptly.
    init(name: String?, isSlow: Bool = false) {
        self.name = name
        self.isSlow = isSlow
    }

    var askCount: Int { lock.withLock { asks } }

    func placeName(for coordinates: Coordinates) async -> String? {
        lock.withLock { asks += 1 }

        if isSlow {
            guard (try? await Task.sleep(for: .seconds(30))) != nil else { return nil }
        }

        return name
    }
}

/// Reachability the test decides.
///
/// `ReachabilityMonitor` would report whatever the machine running the suite is plugged into,
/// which is the one thing a test about being offline cannot use.
@MainActor
final class StubReachability: NetworkReachability {
    let isOnline: Bool

    init(isOnline: Bool) {
        self.isOnline = isOnline
    }
}

/// A layout use case over an empty store, which reads as `HomeLayout.default`.
///
/// Most of Home's tests are about prayer times and have no opinion about the arrangement — this
/// keeps them from having to say so in five lines each.
@MainActor
enum HomeLayoutFixtures {
    static func getLayout(
        _ store: any SettingsStore = InMemorySettingsStore()
    ) -> GetHomeLayoutUseCase {
        GetHomeLayoutUseCase(repository: HomeLayoutRepository(settingsStore: store))
    }
}
