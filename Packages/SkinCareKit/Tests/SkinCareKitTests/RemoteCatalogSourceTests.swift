import Foundation
import Testing
@testable import SkinCareKit

@Suite("Remote catalog source")
struct RemoteCatalogSourceTests {
    private func uniqueURL() -> URL { URL(string: "https://catalog-\(UUID().uuidString).example/catalog.json")! }

    @Test("sends If-None-Match and bypasses the URL cache")
    func sendsConditionalHeaders() async throws {
        let url = uniqueURL()
        StubURLProtocol.register(url) { _ in StubReply(status: 304) }
        let source = RemoteCatalogSource(url: url, session: StubURLProtocol.makeSession(), minimumProducts: 1)
        _ = try await source.fetch(ifNoneMatch: "\"v1\"")
        let request = try #require(StubURLProtocol.lastRequest(for: url))
        #expect(request.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test("304 → notModified")
    func notModified() async throws {
        let url = uniqueURL()
        StubURLProtocol.register(url) { _ in StubReply(status: 304) }
        let source = RemoteCatalogSource(url: url, session: StubURLProtocol.makeSession(), minimumProducts: 1)
        let result = try await source.fetch(ifNoneMatch: "\"v1\"")
        #expect(result == .notModified)
    }

    @Test("200 with a valid document → updated with the response ETag")
    func updated() async throws {
        let url = uniqueURL()
        let catalog = TestCatalogs.make(productCount: 3)
        let body = try CatalogCodec.encode(catalog)
        StubURLProtocol.register(url) { _ in
            StubReply(status: 200, headers: ["ETag": "\"v2\"", "Content-Type": "application/json"], body: body)
        }
        let source = RemoteCatalogSource(url: url, session: StubURLProtocol.makeSession(), minimumProducts: 1)
        let result = try await source.fetch(ifNoneMatch: nil)
        #expect(result == .updated(catalog, etag: "\"v2\""))
    }

    @Test("200 with a document below the minimum → CatalogError, nothing returned")
    func invalidDocumentRejected() async throws {
        let url = uniqueURL()
        let body = try CatalogCodec.encode(TestCatalogs.make(productCount: 2))
        StubURLProtocol.register(url) { _ in StubReply(status: 200, body: body) }
        let source = RemoteCatalogSource(url: url, session: StubURLProtocol.makeSession(), minimumProducts: 5)
        await #expect(throws: CatalogError.tooFewProducts(valid: 2, minimum: 5)) {
            try await source.fetch(ifNoneMatch: nil)
        }
    }

    @Test("HTTP 500 → httpStatus error")
    func serverError() async throws {
        let url = uniqueURL()
        StubURLProtocol.register(url) { _ in StubReply(status: 500, body: Data("boom".utf8)) }
        let source = RemoteCatalogSource(url: url, session: StubURLProtocol.makeSession(), minimumProducts: 1)
        await #expect(throws: RemoteCatalogError.httpStatus(500)) {
            try await source.fetch(ifNoneMatch: nil)
        }
    }
}
