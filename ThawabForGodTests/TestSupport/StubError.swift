//
//  StubError.swift
//  ThawabForGodTests
//

import Foundation

/// Something for a stub to fail with that is `Sendable`, unlike `any Error`.
///
/// Shared by suites whose doubles need a failure and nothing more specific than "it failed" — the
/// assertion is about what the caller does next, never about the error itself.
nonisolated struct StubError: Error, Equatable {}
