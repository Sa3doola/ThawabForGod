//
//  MockURLProtocol.swift
//  ThawabForGodTests
//

import Foundation

/// Intercepts requests on an ephemeral session so networking can be tested without a network.
///
/// The handler is class-level state — `URLProtocol` instances are created by `URLSession` —
/// so it is guarded by a lock. `Mutex` would be the modern choice but is iOS 18+.
nonisolated final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

    static func setHandler(_ handler: Handler?) {
        lock.withLock { self.handler = handler }
    }

    private static var currentHandler: Handler? {
        lock.withLock { handler }
    }

    /// A session that routes every request through this protocol.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func respond(statusCode: Int = 200, body: Data) {
        setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
    }

    static func fail(with error: URLError) {
        setHandler { _ in throw error }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
