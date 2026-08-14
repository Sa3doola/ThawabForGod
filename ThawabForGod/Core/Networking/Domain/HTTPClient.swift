//
//  HTTPClient.swift
//  ThawabForGod
//

import Foundation

/// Fetches and decodes a value. `async` throughout, so cancellation propagates through the
/// task tree without a single completion handler.
nonisolated protocol HTTPClient: Sendable {
    func get<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: Response.Type
    ) async throws -> Response
}

nonisolated extension HTTPClient {
    func get<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        try await get(endpoint, as: Response.self)
    }
}
