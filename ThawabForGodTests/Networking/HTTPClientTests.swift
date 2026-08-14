//
//  HTTPClientTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// Serialized: `MockURLProtocol`'s handler is class-level state, so tests sharing it cannot
/// run in parallel — Swift Testing parallelises within a suite by default.
@Suite(.serialized)
struct HTTPClientTests {
    private let endpoint = Endpoint(
        baseURL: URL(string: "https://example.invalid")!,
        path: "resource",
        queryItems: [URLQueryItem(name: "locale", value: "ar")]
    )

    private func makeClient() -> URLSessionHTTPClient {
        URLSessionHTTPClient(session: MockURLProtocol.makeSession())
    }

    // MARK: Request building

    @Test func buildsRequestFromEndpoint() throws {
        let request = try endpoint.urlRequest()

        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://example.invalid/resource?locale=ar")
    }

    @Test func carriesHeaders() throws {
        var endpoint = endpoint
        endpoint.headers = ["Accept": "application/json"]

        let request = try endpoint.urlRequest()

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    // MARK: Decoding

    @Test func decodesSuccessfulResponse() async throws {
        MockURLProtocol.respond(body: Data(#"{"id":1,"title":"Al-Fatiha"}"#.utf8))

        let resource = try await makeClient().get(endpoint, as: SampleResource.self)

        #expect(resource == SampleResource(id: 1, title: "Al-Fatiha"))
    }

    // MARK: Error mapping

    @Test func mapsNonSuccessStatusToStatusError() async throws {
        MockURLProtocol.respond(statusCode: 404, body: Data("missing".utf8))

        await #expect(throws: HTTPError.self) {
            try await makeClient().get(endpoint, as: SampleResource.self)
        }

        do {
            _ = try await makeClient().get(endpoint, as: SampleResource.self)
            Issue.record("Expected a status error")
        } catch let error as HTTPError {
            guard case .status(let code, _) = error else {
                Issue.record("Expected .status, got \(error)")
                return
            }
            #expect(code == 404)
            #expect(error.isRecoverable == false)
        }
    }

    @Test func mapsServerErrorsAsRecoverable() async throws {
        MockURLProtocol.respond(statusCode: 503, body: Data())

        do {
            _ = try await makeClient().get(endpoint, as: SampleResource.self)
            Issue.record("Expected a status error")
        } catch let error as HTTPError {
            #expect(error.isRecoverable)
        }
    }

    @Test func mapsMalformedPayloadToDecodingError() async throws {
        MockURLProtocol.respond(body: Data(#"{"id":"one"}"#.utf8))

        do {
            _ = try await makeClient().get(endpoint, as: SampleResource.self)
            Issue.record("Expected a decoding error")
        } catch let error as HTTPError {
            guard case .decoding = error else {
                Issue.record("Expected .decoding, got \(error)")
                return
            }
            #expect(error.isRecoverable == false)
        }
    }

    @Test func mapsTransportFailureToTransportError() async throws {
        MockURLProtocol.fail(with: URLError(.notConnectedToInternet))

        do {
            _ = try await makeClient().get(endpoint, as: SampleResource.self)
            Issue.record("Expected a transport error")
        } catch let error as HTTPError {
            guard case .transport(let urlError) = error else {
                Issue.record("Expected .transport, got \(error)")
                return
            }
            #expect(urlError.code == .notConnectedToInternet)
            // Being offline is the normal case for this app, and it is retryable.
            #expect(error.isRecoverable)
        }
    }

    @Test func surfacesCancellationAsCancellation() async throws {
        MockURLProtocol.fail(with: URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            try await makeClient().get(endpoint, as: SampleResource.self)
        }
    }
}
