import Foundation

/// Esito del controllo di qualità di uno snapshot: usato dal builder (`verify`) e dal test del Kit
/// sullo snapshot incluso nell'app, così le soglie vivono in un posto solo.
public struct CatalogQualityReport: Sendable, Equatable {
    public var productCount = 0
    public var categoryCount = 0
    public var issues: [String] = []
    public var passes: Bool { issues.isEmpty }

    public init(productCount: Int = 0, categoryCount: Int = 0, issues: [String] = []) {
        self.productCount = productCount
        self.categoryCount = categoryCount
        self.issues = issues
    }
}

public enum CatalogQuality {
    public struct Thresholds: Sendable {
        public var minimumProducts = 60
        public var minimumCategories = 5
        public var minimumDescriptionLength = 40
        public init() {}
    }

    public static func check(_ catalog: Catalog, thresholds: Thresholds = Thresholds()) -> CatalogQualityReport {
        var report = CatalogQualityReport(
            productCount: catalog.products.count,
            categoryCount: Set(catalog.products.map(\.category.id)).count
        )
        if report.productCount < thresholds.minimumProducts {
            report.issues.append("prodotti: \(report.productCount), minimo \(thresholds.minimumProducts)")
        }
        if report.categoryCount < thresholds.minimumCategories {
            report.issues.append("categorie: \(report.categoryCount), minimo \(thresholds.minimumCategories)")
        }
        if catalog.source.license.trimmingCharacters(in: .whitespaces).isEmpty
            || catalog.source.attribution.trimmingCharacters(in: .whitespaces).isEmpty {
            report.issues.append("licenza o attribuzione mancanti in `source`")
        }

        var seen = Set<String>()
        for product in catalog.products {
            if !seen.insert(product.id).inserted {
                report.issues.append("id duplicato: \(product.id)")
            }
            if !CatalogCodec.isValid(product) {
                report.issues.append("prodotto non valido (nome/marca/descrizione/URL https): \(product.id)")
            }
            if product.description.count < thresholds.minimumDescriptionLength {
                report.issues.append(
                    "descrizione di \(product.description.count) caratteri (minimo \(thresholds.minimumDescriptionLength)): \(product.id)"
                )
            }
        }
        return report
    }
}
