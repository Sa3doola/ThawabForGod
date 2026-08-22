//
//  SystemClockService.swift
//  ThawabForGod
//

import Foundation

/// The real clock: the system's date, and a heartbeat built on `Task.sleep`.
///
/// `Task.sleep` rather than `Timer.publish` or `DispatchSourceTimer` because it is already
/// structured — the task inside the stream is cancelled when the stream is torn down, which
/// happens when whoever is iterating it is cancelled. Nothing to invalidate, nothing to keep a
/// reference to.
///
/// It is a `struct` with no state at all, so `Sendable` is free: every stream owns its own task
/// and shares nothing with the next.
nonisolated struct SystemClockService: ClockService {
    var now: Date { Date() }

    func ticks(every interval: Duration) -> AsyncStream<Date> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: interval)
                    } catch {
                        break // cancelled mid-sleep
                    }
                    continuation.yield(Date())
                }
                continuation.finish()
            }

            // The other half of the cancellation: iterating stops, the stream is deinitialised,
            // and this brings the sleeping task down with it. Without it the loop above would
            // keep waking up to yield into a stream nobody is reading.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
