import Foundation
import Testing
@testable import SkinCareKit

@Suite("Schema v1 optional fields (v0.3)")
struct OptionalFieldsTests {
    @Test("a v0.2 document without the new fields decodes with safe defaults")
    func oldDocumentDecodes() throws {
        let catalog = TestCatalogs.make(productCount: 2)
        var object = try JSONSerialization.jsonObject(with: CatalogCodec.encode(catalog)) as? [String: Any] ?? [:]
        var products = object["products"] as? [[String: Any]] ?? []
        for index in products.indices {
            products[index].removeValue(forKey: "soldInItaly")
            products[index].removeValue(forKey: "countries")
            var image = products[index]["image"] as? [String: Any] ?? [:]
            image.removeValue(forKey: "cutoutURL")
            products[index]["image"] = image
        }
        object["products"] = products
        object.removeValue(forKey: "scope")
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try CatalogCodec.decode(data, minimumProducts: 1)
        #expect(decoded.scope == nil)
        #expect(decoded.products[0].soldInItaly == false)
        #expect(decoded.products[0].countries == [])
        #expect(decoded.products[0].image.cutoutURL == nil)
    }

    @Test("the new fields round-trip through the codec")
    func newFieldsRoundTrip() throws {
        var catalog = TestCatalogs.make(productCount: 1)
        catalog.scope = "Italia in evidenza"
        catalog.products[0].soldInItaly = true
        catalog.products[0].countries = ["italy", "france"]
        catalog.products[0].image.cutoutURL = URL(string: "https://andrew64-bit.github.io/SkinCare/images/8000000000000.png")
        let decoded = try CatalogCodec.decode(CatalogCodec.encode(catalog), minimumProducts: 1)
        #expect(decoded == catalog)
        #expect(decoded.products[0].image.cutoutURL?.lastPathComponent == "8000000000000.png")
    }

    @Test("a non-https cutout URL invalidates the product like the other image URLs")
    func insecureCutoutRejected() throws {
        var catalog = TestCatalogs.make(productCount: 2)
        catalog.products[0].image.cutoutURL = URL(string: "http://example.com/x.png")
        let decoded = try CatalogCodec.decode(CatalogCodec.encode(catalog), minimumProducts: 1)
        #expect(decoded.products.map(\.id) == [catalog.products[1].id])
    }
}
