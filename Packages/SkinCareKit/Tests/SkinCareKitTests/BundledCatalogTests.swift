import Foundation
import Testing
@testable import SkinCareKit

@Suite("Bundled snapshot")
struct BundledCatalogTests {
    @Test("the shipped catalog.json loads and passes the quality gate")
    func snapshotPassesQualityGate() throws {
        let catalog = try BundledCatalog.load()
        let report = CatalogQuality.check(catalog)
        #expect(report.passes, "\(report.issues)")
        #expect(report.productCount >= 60)
        #expect(report.categoryCount >= 5)
    }

    @Test("every shipped product has name, brand, https image URLs and a description of at least 40 characters")
    func everyProductComplete() throws {
        let catalog = try BundledCatalog.load()
        for product in catalog.products {
            #expect(product.name.count >= 3, "\(product.id)")
            #expect(!product.brand.isEmpty, "\(product.id)")
            #expect(product.image.url200.scheme == "https", "\(product.id)")
            #expect(product.image.url400.scheme == "https", "\(product.id)")
            #expect(product.description.count >= 40, "\(product.id)")
            #expect(product.sourceURL.absoluteString.hasPrefix("https://world.openbeautyfacts.org/product/"), "\(product.id)")
        }
    }

    @Test("the shipped catalog declares the licenses and the attribution")
    func licenseBlock() throws {
        let catalog = try BundledCatalog.load()
        #expect(catalog.source.license.contains("ODbL"))
        #expect(catalog.source.license.contains("CC BY-SA 3.0"))
        #expect(catalog.source.attribution.contains("Open Beauty Facts"))
        #expect(catalog.schemaVersion == Catalog.currentSchemaVersion)
    }
}
