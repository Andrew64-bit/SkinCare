import Foundation
import Testing
@testable import SkinCareKit

@Suite("Catalog model")
struct CatalogModelTests {
    @Test("encode → decode round trip preserves every field")
    func roundTrip() throws {
        let catalog = TestCatalogs.make(productCount: 2)
        let data = try CatalogCodec.encode(catalog)
        let decoded = try CatalogCodec.decode(data, minimumProducts: 1)
        #expect(decoded == catalog)
        #expect(decoded.products.count == 2)
        #expect(decoded.products[0].category.label == "Creme viso")
    }

    @Test("dates are encoded as ISO 8601 strings, not numbers")
    func iso8601Dates() throws {
        let catalog = TestCatalogs.make(productCount: 1)
        let object = try JSONSerialization.jsonObject(with: CatalogCodec.encode(catalog))
        let dict = try #require(object as? [String: Any])
        #expect(dict["generatedAt"] as? String == "2026-09-19T10:00:00Z")
    }
}
