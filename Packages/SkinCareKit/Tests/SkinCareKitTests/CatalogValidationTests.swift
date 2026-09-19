import Foundation
import Testing
@testable import SkinCareKit

@Suite("Catalog validation")
struct CatalogValidationTests {
    private func data(_ catalog: Catalog) throws -> Data { try CatalogCodec.encode(catalog) }

    @Test("a document with a future schema version is rejected")
    func futureSchemaRejected() throws {
        let catalog = TestCatalogs.make(productCount: 3, schemaVersion: 2)
        #expect(throws: CatalogError.unsupportedSchema(2)) {
            try CatalogCodec.decode(data(catalog), minimumProducts: 1)
        }
    }

    @Test("a product without brand is dropped, the rest survives")
    func invalidProductDropped() throws {
        var catalog = TestCatalogs.make(productCount: 3)
        catalog.products[1].brand = "   "
        let decoded = try CatalogCodec.decode(data(catalog), minimumProducts: 1)
        #expect(decoded.products.map(\.id) == [catalog.products[0].id, catalog.products[2].id])
    }

    @Test("a product whose name is shorter than 3 characters is dropped")
    func shortNameDropped() throws {
        var catalog = TestCatalogs.make(productCount: 2)
        catalog.products[0].name = "Ab"
        let decoded = try CatalogCodec.decode(data(catalog), minimumProducts: 1)
        #expect(decoded.products.map(\.id) == [catalog.products[1].id])
    }

    @Test("a product with a non-https image URL is dropped")
    func insecureImageDropped() throws {
        var catalog = TestCatalogs.make(productCount: 2)
        catalog.products[0].image.url200 = URL(string: "http://images.openbeautyfacts.org/x.200.jpg")!
        let decoded = try CatalogCodec.decode(data(catalog), minimumProducts: 1)
        #expect(decoded.products.map(\.id) == [catalog.products[1].id])
    }

    @Test("a product with an empty description is dropped")
    func emptyDescriptionDropped() throws {
        var catalog = TestCatalogs.make(productCount: 2)
        catalog.products[1].description = ""
        let decoded = try CatalogCodec.decode(data(catalog), minimumProducts: 1)
        #expect(decoded.products.map(\.id) == [catalog.products[0].id])
    }

    @Test("fewer valid products than the minimum → the whole document is rejected")
    func tooFewProductsRejected() throws {
        var catalog = TestCatalogs.make(productCount: 3)
        catalog.products[2].brand = ""
        #expect(throws: CatalogError.tooFewProducts(valid: 2, minimum: 3)) {
            try CatalogCodec.decode(data(catalog), minimumProducts: 3)
        }
    }

    @Test("duplicate barcodes: the first occurrence wins")
    func duplicatesDeduplicated() throws {
        var catalog = TestCatalogs.make(productCount: 3)
        catalog.products[2].id = catalog.products[0].id
        catalog.products[2].name = "Duplicato"
        let decoded = try CatalogCodec.decode(data(catalog), minimumProducts: 1)
        #expect(decoded.products.count == 2)
        #expect(decoded.products[0].name == catalog.products[0].name)
    }

    @Test("malformed JSON → corruptData")
    func malformedJSON() {
        let bytes = Data("{ \"schemaVersion\": 1, \"products\": [ ".utf8)
        #expect(throws: CatalogError.self) {
            try CatalogCodec.decode(bytes, minimumProducts: 1)
        }
    }
}
