import Foundation
import Synchronization

/// Risponde alle richieste HTTP dei test senza rete. Gli handler sono registrati per URL esatto, così
/// i test possono girare in parallelo senza interferire.
final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (status: Int, headers: [String: String], body: Data)

    private static let handlers = Mutex<[String: Handler]>([:])
    private static let requests = Mutex<[String: URLRequest]>([:])

    static func register(_ url: URL, handler: @escaping Handler) {
        handlers.withLock { $0[url.absoluteString] = handler }
    }

    static func lastRequest(for url: URL) -> URLRequest? {
        requests.withLock { $0[url.absoluteString] }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let client else { return }
        Self.requests.withLock { $0[url.absoluteString] = request }
        guard let handler = Self.handlers.withLock({ $0[url.absoluteString] }) else {
            client.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        do {
            let reply = try handler(request)
            let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: reply.body)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
