//
//  SampleResource.swift
//  ThawabForGod
//

import Foundation

/// A minimal payload proving the request → decode → typed-error pipeline end to end.
///
/// Exercised only by tests against a mocked `URLProtocol`: the app makes no network call at
/// runtime. Replace it with a real resource when one exists; do not build features on it.
nonisolated struct SampleResource: Codable, Equatable, Sendable {
    let id: Int
    let title: String
}
