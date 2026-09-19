import Foundation
import Synchronization
import Testing
import SkinCareKit
@testable import CatalogBuilderCore

/// Risposte precostituite per (tag, pagina); registra le chiamate.
final class FakeSearch: OBFSearching {
    private let pages: Mutex<[String: Result<OBFSearchResponse, any Error>]>
    private let products: Mutex<[String: OBFProduct]>
    private let calls = Mutex<[String]>([])

    init(_ pages: [String: Result<OBFSearchResponse, any Error>], products: [String: OBFProduct] = [:]) {
        self.pages = Mutex(pages)
        self.products = Mutex(products)
    }

    var recordedCalls: [String] { calls.withLock { $0 } }
    /// Solo le ricerche per popolarità (senza ricerche mirate «?…» e senza i recuperi del credito foto).
    var searchCalls: [String] { recordedCalls.filter { !$0.hasPrefix("product:") && !$0.contains("?") } }
    var targetedCalls: [String] { recordedCalls.filter { $0.contains("?") } }

    func search(categoryTag: String, page: Int) async throws -> OBFSearchResponse {
        try await search(categoryTag: categoryTag, page: page, filters: [:])
    }

    func search(categoryTag: String, page: Int, filters: [String: String]) async throws -> OBFSearchResponse {
        let pairs = filters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        let suffix = filters.isEmpty ? "" : "?" + pairs.joined(separator: "&")
        let key = "\(categoryTag)#\(page)\(suffix)"
        calls.withLock { $0.append(key) }
        guard let result = pages.withLock({ $0[key] }) else {
            // Le ricerche mirate senza risposta registrata sono vuote (nessun prodotto italiano).
            if !filters.isEmpty {
                return try OBFDecoder.searchResponse(from: Data("{\"count\":0,\"page_size\":100,\"products\":[]}".utf8))
            }
            throw OBFClientError.httpStatus(404)
        }
        return try result.get()
    }

    func product(code: String) async throws -> OBFProduct? {
        calls.withLock { $0.append("product:\(code)") }
        return products.withLock { $0[code] }
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
             "ingredients_text":"Aqua, Glycerin, Alcohol Denat., Parfum, Limonene",
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
        var expected = CategoryReport(tag: "facial-creams", pagesFetched: 1, productsSeen: 100, productsSelected: 20)
        expected.targetedPages = 2 // le due ricerche mirate (Italia) rispondono vuote in questo test
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
        #expect(search.searchCalls == ["cleansers#1", "cleansers#2"])
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
        #expect(search.searchCalls == ["cleansers#1"])
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

    @Test("when the search page lacks image metadata, the photo credit is recovered from the product endpoint")
    func creditRecoveredFromProductEndpoint() async throws {
        let page = try syntheticPage(from: 0, count: 5, pageCount: 1) // products without `images`
        let detailJSON = """
        {"code":"90000","product_name":"Prodotto 0","images":{"1":{"uploader":"jean-yves"},"front_it":{"imgid":"1","rev":"3"}}}
        """
        let detail = try OBFDecoder.product(from: Data(detailJSON.utf8))
        let search = FakeSearch(["cleansers#1": .success(page)], products: ["90000": detail])
        let assembler = CatalogAssembler(search: search, categories: categories(["cleansers"]), now: { now })
        let result = try await assembler.build()
        let first = try #require(result.catalog.products.first { $0.id == "90000" })
        #expect(first.image.credit.uploader == "jean-yves")
        let others = result.catalog.products.filter { $0.id != "90000" }
        #expect(others.allSatisfy { $0.image.credit.uploader == OBFMapper.fallbackUploader })
        #expect(search.recordedCalls.filter { $0.hasPrefix("product:") }.count == 5)
    }

    @Test("products with the same brand, name and quantity are collapsed: the first (most scanned) stays")
    func duplicateVariantsCollapsed() async throws {
        let products = (0..<3).map { index in
            """
            {"code":"7000\(index)","product_name":"Nivea Creme","brands":"Nivea","quantity":"150 ml",
             "ingredients_text":"Aqua, Paraffinum Liquidum, Cera Microcristallina, Glycerin, Parfum",
             "image_front_url":"https://images.openbeautyfacts.org/p/\(index)/front.400.jpg","last_modified_t":1780000000}
            """
        } + ["""
            {"code":"70009","product_name":"Nivea Creme","brands":"Nivea","quantity":"30 ml",
             "ingredients_text":"Aqua, Paraffinum Liquidum, Cera Microcristallina, Glycerin, Parfum",
             "image_front_url":"https://images.openbeautyfacts.org/p/9/front.400.jpg","last_modified_t":1780000000}
            """]
        let json = """
        {"count":4,"page":1,"page_count":1,"page_size":100,"products":[\(products.joined(separator: ","))]}
        """
        let page = try OBFDecoder.searchResponse(from: Data(json.utf8))
        let search = FakeSearch(["facial-creams#1": .success(page)])
        let assembler = CatalogAssembler(search: search, categories: categories(["facial-creams"]), now: { now })
        let result = try await assembler.build()
        #expect(result.catalog.products.map(\.id) == ["70000", "70009"])
    }

    // MARK: - v0.3 Italia

    private func page(_ products: [String], pageCount: Int = 1) throws -> OBFSearchResponse {
        let json = """
        {"count":\(products.count),"page":1,"page_count":\(pageCount),"page_size":100,
         "products":[\(products.joined(separator: ","))]}
        """
        return try OBFDecoder.searchResponse(from: Data(json.utf8))
    }

    private func item(_ code: String, name: String, countries: [String] = [], languages: [String] = []) -> String {
        let cs = countries.map { "\"\($0)\"" }.joined(separator: ",")
        let ls = languages.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"code":"\(code)","product_name":"\(name)","brands":"Marca \(code)",
         "quantity":"50 ml",
         "ingredients_text":"Aqua, Glycerin, Alcohol Denat., Parfum, Limonene",
         "countries_tags":[\(cs)],"languages_tags":[\(ls)],
         "image_front_url":"https://images.openbeautyfacts.org/p/\(code)/front.400.jpg","last_modified_t":1780000000}
        """
    }

    @Test("Italian products come first in each category, popularity order preserved within the two groups")
    func italianProductsFirst() async throws {
        let search = FakeSearch(["cleansers#1": .success(try page([
            item("1", name: "Alfa", countries: ["en:france"]),
            item("2", name: "Beta", countries: ["en:italy"]),
            item("3", name: "Gamma", countries: ["en:germany"]),
            item("4", name: "Delta", languages: ["en:italian"])
        ]))])
        let assembler = CatalogAssembler(search: search, categories: categories(["cleansers"]), now: { now })
        let result = try await assembler.build()
        #expect(result.catalog.products.map(\.id) == ["2", "4", "1", "3"])
        #expect(result.catalog.products.map(\.soldInItaly) == [true, true, false, false])
    }

    @Test("targeted Italian searches add products missing from the popularity pages, without duplicates")
    func targetedItalianSearches() async throws {
        let search = FakeSearch([
            "cleansers#1": .success(try page([
                item("1", name: "Alfa", countries: ["en:france"]), item("2", name: "Beta", countries: ["en:italy"])
            ])),
            "cleansers#1?countries_tags=en:italy": .success(try page([
                item("2", name: "Beta", countries: ["en:italy"]), item("9", name: "Zeta", countries: ["en:italy"])
            ])),
            "cleansers#1?languages_tags=en:italian": .success(try page([item("8", name: "Ypsilon", languages: ["en:italian"])]))
        ])
        let assembler = CatalogAssembler(search: search, categories: categories(["cleansers"]), now: { now })
        let result = try await assembler.build()
        #expect(result.catalog.products.map(\.id) == ["2", "9", "8", "1"])
        #expect(search.targetedCalls.contains("cleansers#1?countries_tags=en:italy"))
        #expect(search.targetedCalls.contains("cleansers#1?languages_tags=en:italian"))
        #expect(result.reports.first?.italianProducts == 3)
    }

    @Test("the catalog declares its scope and the v1 categories include hand creams and micellar waters")
    func scopeAndCategories() async throws {
        let search = FakeSearch(["cleansers#1": .success(try page([item("1", name: "Alfa")]))])
        let assembler = CatalogAssembler(search: search, categories: categories(["cleansers"]), now: { now })
        let catalog = try await assembler.build().catalog
        #expect(catalog.scope?.contains("Italia") == true)
        #expect(Categories.v1.map(\.tag).contains("hand-creams"))
        #expect(Categories.v1.map(\.tag).contains("micellar-waters"))
    }
}
