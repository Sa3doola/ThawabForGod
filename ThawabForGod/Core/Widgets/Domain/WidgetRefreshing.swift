//
//  WidgetRefreshing.swift
//  ThawabForGod
//

import Foundation

/// Tells the widgets their inputs have changed.
///
/// A protocol over one call, and it earns the indirection twice. `WidgetCenter` is a system
/// singleton with no fake, so a test that asserted "a settings change reloads the timelines"
/// could not otherwise be written. And it keeps `WidgetKit` out of the composition root, which
/// on macOS matters — the framework is available there, but the trigger is the same either way
/// and a `#if` at the call site would be one more thing to keep in step.
///
/// `nonisolated` and `Sendable` because the module default is `MainActor` and nothing about
/// asking the system to reload belongs to a thread.
nonisolated protocol WidgetRefreshing: Sendable {
    /// Discards every rendered timeline and asks each widget for a new one.
    ///
    /// Whole-bundle rather than per-kind: every widget this app ships is a view of the same
    /// prayer schedule, so anything that invalidates one invalidates all of them, and naming
    /// kinds here would be a list to forget to add to.
    func reloadAll()
}
