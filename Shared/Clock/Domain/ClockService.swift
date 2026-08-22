//
//  ClockService.swift
//  ThawabForGod
//

import Foundation

/// The current instant, and a heartbeat.
///
/// Two things that are the same dependency: a screen counting down needs to know what time it is
/// *and* to be told when to look again. Splitting them across a `now` closure and a timer built
/// inside a view model is how a countdown becomes untestable — the test either sleeps for real or
/// reaches past the loop to call the tick by hand.
///
/// `AsyncStream` rather than `Timer` or Combine: it is cancelled by the structured task that
/// consumes it, so a screen that goes away takes its heartbeat with it and there is no stored
/// timer for anyone to forget to invalidate. It also lets a test drive the beat by hand — see
/// `TestClock`, which yields on demand and never sleeps.
///
/// `nonisolated` and `Sendable`: the module default is `MainActor`, but a clock has no business
/// being pinned to it, and the stream is consumed from whatever task asks for it.
nonisolated protocol ClockService: Sendable {
    /// What time it is now. Read on every recomputation rather than captured, so a view model
    /// never holds a stale instant across a suspension.
    var now: Date { get }

    /// A tick every `interval`, until the consuming task is cancelled.
    ///
    /// The first value arrives *after* one interval, not immediately: a caller that needs the
    /// current instant already has `now`, and a leading tick would double the first update.
    func ticks(every interval: Duration) -> AsyncStream<Date>
}
