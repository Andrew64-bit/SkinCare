import Foundation
import Synchronization

struct StubReply: Sendable {
    var status: Int
    var headers: [String: String] = [:]
    var body = Data()
}

/// Risponde alle richieste HTTP dei test senza rete; handler registrati per URL esatto (senza query).
class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> StubReply

    private static let handlers = Mutex<[String: Handler]>([:])
    private static let requests = Mutex<[String: [URLRequest]]>([:])

    /// Registra un handler per tutte le richieste il cui URL (senza query) è `prefix`.
    static func register(prefix: String, handler: @escaping Handler) {
        handlers.withLock { $0[prefix] = handler }
    }

    static func requests(prefix: String) -> [URLRequest] {
        requests.withLock { $0[prefix] ?? [] }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    private static func prefix(of request: URLRequest) -> String? {
        guard let url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.query = nil
        return components.string
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client, let prefix = Self.prefix(of: request), let url = request.url else { return }
        Self.requests.withLock { $0[prefix, default: []].append(request) }
        guard let handler = Self.handlers.withLock({ $0[prefix] }) else {
            client.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        do {
            let reply = try handler(request)
            let response = HTTPURLResponse(
                url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: reply.body)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
