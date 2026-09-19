import Foundation
import Testing
@testable import SkinCareKit

@Suite("Catalog quality gate")
struct CatalogQualityTests {
    private func catalog(products: Int, categories: Int) -> Catalog {
        var catalog = TestCatalogs.make(productCount: products)
        for index in catalog.products.indices {
            let slot = index % categories
            catalog.products[index].category = ProductCategory(id: "cat-\(slot)", label: "Categoria \(slot)")
        }
        return catalog
    }

    @Test("60 products in 5 categories with long descriptions pass")
    func passes() {
        let report = CatalogQuality.check(catalog(products: 60, categories: 5))
        #expect(report.passes)
        #expect(report.productCount == 60)
        #expect(report.categoryCount == 5)
    }

    @Test("59 products fail with an issue naming the product count")
    func tooFewProducts() {
        let report = CatalogQuality.check(catalog(products: 59, categories: 5))
        #expect(!report.passes)
        #expect(report.issues.contains { $0.contains("59") && $0.contains("60") })
    }

    @Test("4 categories fail")
    func tooFewCategories() {
        let report = CatalogQuality.check(catalog(products: 60, categories: 4))
        #expect(report.issues.contains { $0.contains("categor") })
    }

    @Test("a description shorter than 40 characters is reported with the product id")
    func shortDescription() {
        var catalog = catalog(products: 60, categories: 5)
        catalog.products[7].description = "Troppo corta."
        let report = CatalogQuality.check(catalog)
        #expect(report.issues.contains { $0.contains(catalog.products[7].id) })
    }

    @Test("a product missing an https image is reported")
    func missingImage() {
        var catalog = catalog(products: 60, categories: 5)
        catalog.products[3].image.url400 = URL(string: "http://example.com/x.jpg")!
        let report = CatalogQuality.check(catalog)
        #expect(report.issues.contains { $0.contains(catalog.products[3].id) })
    }

    @Test("duplicate ids are reported")
    func duplicates() {
        var catalog = catalog(products: 61, categories: 5)
        catalog.products[60].id = catalog.products[0].id
        let report = CatalogQuality.check(catalog)
        #expect(report.issues.contains { $0.lowercased().contains("duplic") })
    }

    @Test("an empty license or attribution is reported")
    func licenseMissing() {
        var catalog = catalog(products: 60, categories: 5)
        catalog.source.license = ""
        let report = CatalogQuality.check(catalog)
        #expect(report.issues.contains { $0.lowercased().contains("licen") })
    }
}
