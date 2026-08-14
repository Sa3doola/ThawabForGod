//
//  HTTPError.swift
//  ThawabForGod
//

import Foundation

/// Everything that can go wrong on the way to a decoded value, split so a caller can tell
/// "you are offline" from "the server is broken" from "we cannot read this".
nonisolated enum HTTPError: Error {
    case invalidURL
    case transport(URLError)
    case status(code: Int, data: Data)
    case decoding(any Error)

    /// True when retrying later might work — the distinction an offline-first app cares about.
    var isRecoverable: Bool {
        switch self {
        case .transport: true
        case .status(let code, _): code >= 500
        case .invalidURL, .decoding: false
        }
    }
}
