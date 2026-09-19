import Foundation
import Synchronization
import Testing
@testable import CatalogBuilderCore

final class SleepRecorder: Sendable {
    let sleeps = Mutex<[TimeInterval]>([])
}

@Suite("Open Beauty Facts client")
struct OBFClientTests {
    private static let userAgent = "SkinCareCatalogBuilder/0.1 (test@example.com)"

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func uniqueBase() -> URL { URL(string: "https://obf-\(UUID().uuidString).example")! }

    private func query(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    @Test("the search URL targets /api/v2/search with the documented parameters")
    func searchURL() {
        let client = OBFClient(userAgent: Self.userAgent, rateLimiter: RateLimiter(minimumInterval: 0))
        let url = client.searchURL(categoryTag: "facial-creams", page: 2)
        #expect(url.host() == "world.openbeautyfacts.org")
        #expect(url.path() == "/api/v2/search")
        let params = query(of: url)
        #expect(params["categories_tags"] == "en:facial-creams")
        #expect(params["sort_by"] == "unique_scans_n")
        #expect(params["page_size"] == "100")
        #expect(params["page"] == "2")
        #expect(params["lc"] == "it")
        let fields = (params["fields"] ?? "").split(separator: ",").map(String.init)
        #expect(fields.contains("images"))
        #expect(fields.contains("product_name"))
        #expect(fields.contains("image_front_url"))
        #expect(fields.contains("ingredients_text"))
        #expect(fields.contains("ingredients_n"))
    }

    @Test("every request carries the identifying User-Agent")
    func userAgentHeader() async throws {
        let base = uniqueBase()
        let body = try fixture("search_facial_creams_page1")
        StubURLProtocol.register(prefix: base.absoluteString + "/api/v2/search") { _ in StubReply(status: 200, body: body) }
        let client = OBFClient(
            userAgent: Self.userAgent, rateLimiter: RateLimiter(minimumInterval: 0),
            session: StubURLProtocol.makeSession(), baseURL: base
        )
        _ = try await client.search(categoryTag: "facial-creams", page: 1)
        let request = try #require(StubURLProtocol.requests(prefix: base.absoluteString + "/api/v2/search").first)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == Self.userAgent)
    }

    @Test("a 200 response decodes into the search page")
    func decodesSearchPage() async throws {
        let base = uniqueBase()
        let body = try fixture("search_facial_creams_page1")
        StubURLProtocol.register(prefix: base.absoluteString + "/api/v2/search") { _ in StubReply(status: 200, body: body) }
        let client = OBFClient(
            userAgent: Self.userAgent, rateLimiter: RateLimiter(minimumInterval: 0),
            session: StubURLProtocol.makeSession(), baseURL: base
        )
        let page = try await client.search(categoryTag: "facial-creams", page: 1)
        #expect(page.products.count == 100)
        #expect(page.count == 465)
    }

    @Test("consecutive searches go through the rate limiter")
    func rateLimited() async throws {
        let base = uniqueBase()
        let body = try fixture("search_facial_creams_page1")
        StubURLProtocol.register(prefix: base.absoluteString + "/api/v2/search") { _ in StubReply(status: 200, body: body) }
        let recorder = SleepRecorder()
        let limiter = RateLimiter(
            minimumInterval: 6.5,
            now: { Date(timeIntervalSince1970: 0) },
            sleep: { seconds in recorder.sleeps.withLock { $0.append(seconds) } }
        )
        let client = OBFClient(
            userAgent: Self.userAgent, rateLimiter: limiter, session: StubURLProtocol.makeSession(), baseURL: base
        )
        _ = try await client.search(categoryTag: "facial-creams", page: 1)
        _ = try await client.search(categoryTag: "cleansers", page: 1)
        #expect(recorder.sleeps.withLock { $0 } == [6.5])
    }

    @Test("HTTP 429 surfaces as httpStatus(429)")
    func tooManyRequests() async throws {
        let base = uniqueBase()
        StubURLProtocol.register(prefix: base.absoluteString + "/api/v2/search") { _ in StubReply(status: 429) }
        let client = OBFClient(
            userAgent: Self.userAgent, rateLimiter: RateLimiter(minimumInterval: 0),
            session: StubURLProtocol.makeSession(), baseURL: base
        )
        await #expect(throws: OBFClientError.httpStatus(429)) {
            try await client.search(categoryTag: "facial-creams", page: 1)
        }
    }
}
