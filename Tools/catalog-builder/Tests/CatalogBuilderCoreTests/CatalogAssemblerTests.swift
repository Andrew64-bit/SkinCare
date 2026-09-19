import Foundation
import Synchronization
import Testing
import SkinCareKit
@testable import CatalogBuilderCore

/// Risposte precostituite per (tag, pagina); registra le chiamate.
final class FakeSearch: OBFSearching {
    private let pages: Mutex<[String: Result<OBFSearchResponse, any Error>]>
    private let calls = Mutex<[String]>([])

    init(_ pages: [String: Result<OBFSearchResponse, any Error>]) {
        self.pages = Mutex(pages)
    }

    var recordedCalls: [String] { calls.withLock { $0 } }

    func search(categoryTag: String, page: Int) async throws -> OBFSearchResponse {
        let key = "\(categoryTag)#\(page)"
        calls.withLock { $0.append(key) }
        guard let result = pages.withLock({ $0[key] }) else { throw OBFClientError.httpStatus(404) }
        return try result.get()
    }
}

@Suite("Catalog assembler")
struct CatalogAssemblerTests {
    private let now = Date(timeIntervalSince1970: 1_789_812_000)

    private func fixturePage() throws -> OBFSearchResponse {
        let url = try #require(Bundle.module.url(
            forResource: "search_facial_creams_page1", withExtension: "json", subdirectory: "Fixtures"
        ))
        return try OBFDecoder.searchResponse(from: Data(contentsOf: url))
    }

    /// Pagina sintetica con `count` prodotti validi numerati da `from`.
    private func syntheticPage(from: Int, count: Int, pageCount: Int, pageSize: Int = 100) throws -> OBFSearchResponse {
        let products = (from..<(from + count)).map { index in
            """
            {"code":"9000\(index)","product_name":"Prodotto \(index)","brands":"Marca","quantity":"50 ml",
             "ingredients_text":"Aqua, Glycerin, Alcohol",
             "image_front_url":"https://images.openbeautyfacts.org/p/\(index)/front.400.jpg","last_modified_t":1780000000}
            """
        }
        let json = """
        {"count":\(count * pageCount),"page":1,"page_count":\(pageCount),"page_size":\(pageSize),
         "products":[\(products.joined(separator: ","))]}
        """
        return try OBFDecoder.searchResponse(from: Data(json.utf8))
    }

    private func categories(_ tags: [String]) -> [CategorySpec] {
        tags.map { CategorySpec(tag: $0, label: $0.capitalized, singular: $0.capitalized) }
    }

    @Test("each category is capped at perCategory products, in page order")
    func perCategoryCap() async throws {
        let page = try fixturePage()
        let search = FakeSearch(["facial-creams#1": .success(page)])
        let assembler = CatalogAssembler(
            search: search, categories: categories(["facial-creams"]),
            options: AssemblerOptions(perCategory: 20), now: { now }
        )
        let result = try await assembler.build()
        #expect(result.catalog.products.count == 20)
        let expected = CategoryReport(tag: "facial-creams", pagesFetched: 1, productsSeen: 100, productsSelected: 20)
        #expect(result.reports == [expected])
        let firstMapped = try #require(page.products.lazy.compactMap { OBFMapper.map($0, category: Categories.v1[0]) }.first)
        #expect(result.catalog.products[0].id == firstMapped.id)
    }

    @Test("a product already selected in an earlier category is not repeated")
    func crossCategoryDedupe() async throws {
        let page = try fixturePage()
        let search = FakeSearch(["facial-creams#1": .success(page), "anti-aging#1": .success(page)])
        let assembler = CatalogAssembler(
            search: search, categories: categories(["facial-creams", "anti-aging"]),
            options: AssemblerOptions(perCategory: 20), now: { now }
        )
        let result = try await assembler.build()
        let ids = result.catalog.products.map(\.id)
        #expect(ids.count == 40)
        #expect(Set(ids).count == 40)
        #expect(result.catalog.products[20].category.id == "anti-aging")
    }

    @Test("a second page is fetched when the first does not fill the quota, up to maxPagesPerCategory")
    func pagination() async throws {
        let search = FakeSearch([
            "cleansers#1": .success(try syntheticPage(from: 0, count: 5, pageCount: 3)),
            "cleansers#2": .success(try syntheticPage(from: 100, count: 5, pageCount: 3)),
            "cleansers#3": .success(try syntheticPage(from: 200, count: 5, pageCount: 3))
        ])
        let assembler = CatalogAssembler(
            search: search, categories: categories(["cleansers"]),
            options: AssemblerOptions(perCategory: 20, maxPagesPerCategory: 2), now: { now }
        )
        let result = try await assembler.build()
        #expect(search.recordedCalls == ["cleansers#1", "cleansers#2"])
        #expect(result.catalog.products.count == 10)
        #expect(result.reports.first?.pagesFetched == 2)
    }

    @Test("no second page is requested when the first one is the last")
    func stopsAtLastPage() async throws {
        let search = FakeSearch(["cleansers#1": .success(try syntheticPage(from: 0, count: 5, pageCount: 1))])
        let assembler = CatalogAssembler(
            search: search, categories: categories(["cleansers"]),
            options: AssemblerOptions(perCategory: 20, maxPagesPerCategory: 3), now: { now }
        )
        _ = try await assembler.build()
        #expect(search.recordedCalls == ["cleansers#1"])
    }

    @Test("the catalog carries schema 1, the build time and the license block")
    func metadata() async throws {
        let search = FakeSearch(["cleansers#1": .success(try syntheticPage(from: 0, count: 5, pageCount: 1))])
        let assembler = CatalogAssembler(search: search, categories: categories(["cleansers"]), now: { now })
        let catalog = try await assembler.build().catalog
        #expect(catalog.schemaVersion == 1)
        #expect(catalog.generatedAt == now)
        #expect(catalog.source.name == "Open Beauty Facts")
        #expect(catalog.source.url.absoluteString == "https://world.openbeautyfacts.org")
        #expect(catalog.source.license.contains("ODbL"))
        #expect(catalog.source.license.contains("CC BY-SA 3.0"))
        #expect(catalog.source.attribution.contains("Open Beauty Facts"))
    }

    @Test("a failing category fails the whole build: never a partial catalog")
    func failurePropagates() async throws {
        let search = FakeSearch([
            "cleansers#1": .success(try syntheticPage(from: 0, count: 5, pageCount: 1)),
            "sunscreen#1": .failure(OBFClientError.httpStatus(503))
        ])
        let assembler = CatalogAssembler(search: search, categories: categories(["cleansers", "sunscreen"]), now: { now })
        await #expect(throws: OBFClientError.httpStatus(503)) {
            try await assembler.build()
        }
    }
}
