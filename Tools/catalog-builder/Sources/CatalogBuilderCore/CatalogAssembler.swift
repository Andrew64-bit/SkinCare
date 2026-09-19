import Foundation
import SkinCareKit

public struct AssemblerOptions: Sendable {
    public var perCategory = 20
    public var maxPagesPerCategory = 2
    public init(perCategory: Int = 20, maxPagesPerCategory: Int = 2) {
        self.perCategory = perCategory
        self.maxPagesPerCategory = maxPagesPerCategory
    }
}

public struct CategoryReport: Sendable, Equatable {
    public var tag: String
    public var pagesFetched: Int
    public var productsSeen: Int
    public var productsSelected: Int
}

public struct AssemblyResult: Sendable {
    public var catalog: Catalog
    public var reports: [CategoryReport]
}

/// Costruisce il catalogo: per ogni categoria (in ordine) scarica pagine ordinate per popolarità finché
/// la quota è piena o le pagine finiscono, mappa e filtra i prodotti, evita ripetizioni fra categorie.
/// Se una categoria fallisce, fallisce l'intera costruzione: non si pubblica mai un catalogo parziale.
public struct CatalogAssembler: Sendable {
    public static let sourceInfo = CatalogSourceInfo(
        name: "Open Beauty Facts",
        url: URL(string: "https://world.openbeautyfacts.org")!,
        license: "ODbL 1.0 (database) · DbCL 1.0 (contenuti) · CC BY-SA 3.0 (foto)",
        attribution: "Dati: Open Beauty Facts (ODbL) · Foto: contributori Open Beauty Facts (CC BY-SA 3.0)"
    )

    private let search: any OBFSearching
    private let categories: [CategorySpec]
    private let options: AssemblerOptions
    private let now: @Sendable () -> Date
    private let baseURL: URL

    public init(
        search: any OBFSearching,
        categories: [CategorySpec] = Categories.v1,
        options: AssemblerOptions = AssemblerOptions(),
        now: @escaping @Sendable () -> Date = { Date() },
        baseURL: URL = OBFClient.defaultBaseURL
    ) {
        self.search = search
        self.categories = categories
        self.options = options
        self.now = now
        self.baseURL = baseURL
    }

    public func build() async throws -> AssemblyResult {
        var products: [Product] = []
        var selectedIDs = Set<String>()
        var reports: [CategoryReport] = []

        for category in categories {
            var report = CategoryReport(tag: category.tag, pagesFetched: 0, productsSeen: 0, productsSelected: 0)
            var page = 1
            while report.productsSelected < options.perCategory, page <= options.maxPagesPerCategory {
                let response = try await search.search(categoryTag: category.tag, page: page)
                report.pagesFetched += 1
                report.productsSeen += response.products.count
                for dto in response.products where report.productsSelected < options.perCategory {
                    guard let product = OBFMapper.map(dto, category: category, baseURL: baseURL),
                          selectedIDs.insert(product.id).inserted else { continue }
                    products.append(product)
                    report.productsSelected += 1
                }
                let isLastPage = response.products.isEmpty || page >= (response.pageCount ?? 1)
                if isLastPage { break }
                page += 1
            }
            reports.append(report)
        }

        let catalog = Catalog(
            schemaVersion: Catalog.currentSchemaVersion,
            generatedAt: now(),
            source: Self.sourceInfo,
            products: products
        )
        return AssemblyResult(catalog: catalog, reports: reports)
    }
}
