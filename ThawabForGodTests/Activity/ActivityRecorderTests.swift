//
//  ActivityRecorderTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Every activity ever written, in order.
///
/// Safety invariant for `@unchecked Sendable`: `writes` is only ever touched under `lock`. The
/// protocol it witnesses is `nonisolated`, so no actor could witness it instead.
nonisolated final class SpyRecentActivityRepository: RecentActivityRepositoring, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [RecentActivity] = []

    var writes: [RecentActivity] { lock.withLock { log } }

    func recent() async throws -> [RecentActivity] {
        lock.withLock { log }
    }

    func record(_ activity: RecentActivity) async throws {
        lock.withLock { log.append(activity) }
    }
}

/// The debounce, which is the only reason this type exists: a hundred-count dhikr must be one
/// write, not a hundred.
@MainActor
struct ActivityRecorderTests {

    private let when = Date(timeIntervalSince1970: 1_000_000)

    private func makeRecorder(
        delay: Duration = .milliseconds(10)
    ) -> (ActivityRecorder, SpyRecentActivityRepository) {
        let repository = SpyRecentActivityRepository()
        let recorder = ActivityRecorder(
            useCase: RecentActivityUseCase(repository: repository),
            delay: delay
        )
        return (recorder, repository)
    }

    @Test(.timeLimit(.minutes(1)))
    func aRecordedActivityLandsShortly() async {
        let (recorder, repository) = makeRecorder()

        recorder.record(.tasbih(dhikrID: "subhanallah", count: 1, of: 33, at: when))

        while repository.writes.isEmpty {
            await Task.yield()
        }

        #expect(repository.writes.count == 1)
    }

    /// A burst of taps is one write, of the last value — which is the only one that matters.
    @Test(.timeLimit(.minutes(1)))
    func aBurstCollapsesIntoTheLastValue() async {
        let (recorder, repository) = makeRecorder(delay: .milliseconds(60))

        for count in 1...20 {
            recorder.record(.tasbih(dhikrID: "subhanallah", count: count, of: 33, at: when))
        }

        await recorder.flush()

        #expect(repository.writes.count == 1)
        #expect(repository.writes.first?.progressValue == 20)
    }

    /// One pending write *per kind*: a tasbih tap must not cancel an adhkar count that was
    /// waiting to land.
    @Test(.timeLimit(.minutes(1)))
    func onePendingWritePerKind() async {
        let (recorder, repository) = makeRecorder(delay: .milliseconds(60))

        recorder.record(.adhkar(.morning, completed: 7, of: 28, at: when))
        recorder.record(.tasbih(dhikrID: "subhanallah", count: 33, of: 33, at: when))

        await recorder.flush()

        #expect(Set(repository.writes.map(\.kind)) == [.adhkar, .tasbih])
    }

    /// Leaving a screen straight after the last tap is exactly when the delay would lose it.
    @Test(.timeLimit(.minutes(1)))
    func flushingWritesWhatIsStillWaiting() async {
        let (recorder, repository) = makeRecorder(delay: .seconds(30))

        recorder.record(.adhkar(.evening, completed: 3, of: 28, at: when))
        #expect(repository.writes.isEmpty)

        await recorder.flush()

        #expect(repository.writes.map(\.progressValue) == [3])
    }

    @Test(.timeLimit(.minutes(1)))
    func flushingWithNothingWaitingWritesNothing() async {
        let (recorder, repository) = makeRecorder()

        await recorder.flush()

        #expect(repository.writes.isEmpty)
    }

    /// The write is a side effect of doing something else, so a store that cannot take it must
    /// not surface anywhere — see `RecentActivityUseCase`.
    @Test(.timeLimit(.minutes(1)))
    func aFailedWriteIsSwallowed() async {
        nonisolated final class FailingRepository: RecentActivityRepositoring, @unchecked Sendable {
            func recent() async throws -> [RecentActivity] { throw QuranStubError() }
            func record(_ activity: RecentActivity) async throws { throw QuranStubError() }
        }

        let recorder = ActivityRecorder(
            useCase: RecentActivityUseCase(repository: FailingRepository()),
            delay: .milliseconds(1)
        )

        recorder.record(.tasbih(dhikrID: "subhanallah", count: 1, of: 33, at: when))
        await recorder.flush()
    }
}
