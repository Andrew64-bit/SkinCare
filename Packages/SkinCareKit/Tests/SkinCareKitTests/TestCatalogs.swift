import Foundation
@testable import SkinCareKit

enum TestCatalogs {
    static let generatedAt = Date(timeIntervalSince1970: 1_789_812_000) // 2026-09-19T10:00:00Z

    static func make(productCount: Int, generatedAt: Date = generatedAt, schemaVersion: Int = 1) -> Catalog {
        Catalog(
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            source: CatalogSourceInfo(
                name: "Open Beauty Facts",
                url: URL(string: "https://world.openbeautyfacts.org")!,
                license: "ODbL 1.0",
                attribution: "Dati: Open Beauty Facts (ODbL) · Foto: contributori OBF (CC BY-SA 3.0)"
            ),
            products: (0..<productCount).map { product(index: $0) }
        )
    }

    static func product(index: Int, category: ProductCategory = .init(id: "facial-creams", label: "Creme viso")) -> Product {
        let code = String(format: "80000000%05d", index)
        return Product(
            id: code,
            name: "Crema test \(index)",
            brand: "Marca \(index)",
            category: category,
            quantity: "50 ml",
            description: "Crema viso di Marca \(index), 50 ml. Ingredienti principali: Aqua, Glycerin, Cetearyl Alcohol.",
            ingredientsPreview: "Aqua, Glycerin, Cetearyl Alcohol",
            image: ProductImage(
                url400: URL(string: "https://images.openbeautyfacts.org/images/products/\(code)/front.400.jpg")!,
                url200: URL(string: "https://images.openbeautyfacts.org/images/products/\(code)/front.200.jpg")!,
                credit: ImageCredit(
                    uploader: "tester",
                    license: "CC BY-SA 3.0",
                    sourceURL: URL(string: "https://world.openbeautyfacts.org/product/\(code)")!
                )
            ),
            sourceURL: URL(string: "https://world.openbeautyfacts.org/product/\(code)")!,
            lastModified: Date(timeIntervalSince1970: 1_780_000_000)
        )
    }
}
