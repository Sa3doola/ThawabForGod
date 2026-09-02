//
//  ReminderArtworkProviding.swift
//  ThawabForGod
//

import Foundation

/// The picture a reminder's banner carries.
///
/// A `URL` and nothing else, so Domain names no image type and `UserNotificationService` can be
/// tested with a fake that returns a path to a scratch file — or to `nil`, which is the case
/// worth having a test for.
///
/// **The URL is consumed.** `UNNotificationAttachment` *moves* the file it is given into the
/// system's own attachment store, so a conforming type must hand out a fresh file per call rather
/// than the same cached one fifty times. That is a requirement of the protocol, not an
/// implementation detail — see `ReminderArtwork` for how it is met without re-rendering.
@MainActor
protocol ReminderArtworkProviding {
    /// - Returns: a file the caller may consume, or `nil` if none could be produced. `nil` is not
    ///   an error: a reminder without a picture is still a reminder.
    func artwork(for prayer: Prayer) -> URL?
}
