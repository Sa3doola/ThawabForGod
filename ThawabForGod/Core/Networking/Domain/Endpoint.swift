//
//  Endpoint.swift
//  ThawabForGod
//

import Foundation

/// A request described as data. Generic on purpose — no app API is baked in, because the
/// app is offline-first and networking only ever enhances it.
nonisolated struct Endpoint: Equatable, Sendable {
    var baseURL: URL
    var path: String
    var queryItems: [URLQueryItem]
    var headers: [String: String]
    var timeout: TimeInterval

    init(
        baseURL: URL,
        path: String = "",
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.timeout = timeout
    }

    func urlRequest() throws -> URLRequest {
        let url = path.isEmpty ? baseURL : baseURL.appendingPathComponent(path)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw HTTPError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let resolved = components.url else {
            throw HTTPError.invalidURL
        }

        var request = URLRequest(url: resolved, timeoutInterval: timeout)
        request.httpMethod = "GET"
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
