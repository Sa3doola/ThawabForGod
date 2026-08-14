//
//  URLSessionHTTPClient.swift
//  ThawabForGod
//

import Foundation

/// `URLSession`-backed client. Maps every failure onto `HTTPError` in one place, so callers
/// never have to interpret a raw `URLError` or a `DecodingError`.
nonisolated struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func get<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: Response.Type
    ) async throws -> Response {
        let request = try endpoint.urlRequest()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            // A cancelled task must surface as cancellation, not as a network failure.
            if error.code == .cancelled { throw CancellationError() }
            throw HTTPError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError.status(code: http.statusCode, data: data)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw HTTPError.decoding(error)
        }
    }
}
