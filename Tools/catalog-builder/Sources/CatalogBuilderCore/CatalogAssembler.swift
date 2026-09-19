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
    public var italianProducts = 0
    /// Pagine delle ricerche mirate (Italia), separate da quelle per popolarità.
    public var targetedPages = 0
}

public struct AssemblyResult: Sendable {
    public var catalog: Catalog
    public var reports: [CategoryReport]
    /// Crediti foto recuperati dall'endpoint prodotto (la ricerca a volte risponde `images: {}`).
    public var creditsRecovered = 0
}

/// Costruisce il catalogo: per ogni categoria (in ordine) scarica pagine ordinate per popolarità finché
/// la quota è piena o le pagine finiscono, mappa e filtra i prodotti, evita ripetizioni fra categorie.
/// Se una categoria fallisce, fallisce l'intera costruzione: non si pubblica mai un catalogo parziale.
public struct CatalogAssembler: Sendable {
    /// Perimetro dichiarato nel catalogo (scelta di Andrea, 2026-09-19: «Italia in evidenza, resto come riserva»).
    public static let scope = "Italia in evidenza: i prodotti segnalati in vendita in Italia (paese di vendita o "
        + "etichetta in italiano) stanno in cima a ogni categoria; gli altri prodotti europei restano come riserva."
    /// Ricerche mirate per far entrare i prodotti italiani anche se poco scansionati.
    static let italianFilters: [[String: String]] = [["countries_tags": "en:italy"], ["languages_tags": "en:italian"]]

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

    /// Stesso prodotto con barcode diversi (mercati, confezioni): marca + nome + formato normalizzati.
    /// Le pagine sono ordinate per popolarità, quindi resta la variante più scansionata.
    static func variantKey(of product: Product) -> String {
        func fold(_ text: String) -> String {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .lowercased()
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
        }
        return "\(fold(product.brand))|\(fold(product.name))|\(fold(product.quantity ?? ""))"
    }

    public func build() async throws -> AssemblyResult {
        var products: [Product] = []
        var selectedIDs = Set<String>()
        var selectedVariants = Set<String>()
        var reports: [CategoryReport] = []

        for category in categories {
            var report = CategoryReport(tag: category.tag, pagesFetched: 0, productsSeen: 0, productsSelected: 0)
            var italian: [Product] = []
            var others: [Product] = []

            func take(_ dto: OBFProduct) {
                guard let product = OBFMapper.map(dto, category: category, baseURL: baseURL),
                      selectedIDs.insert(product.id).inserted,
                      selectedVariants.insert(Self.variantKey(of: product)).inserted else { return }
                if product.soldInItaly { italian.append(product) } else { others.append(product) }
            }

            // 1. Ricerche mirate: tutti i prodotti italiani della categoria (sono pochi, nessun tetto).
            for filters in Self.italianFilters {
                var page = 1
                while page <= options.maxPagesPerCategory {
                    let response = try await search.search(categoryTag: category.tag, page: page, filters: filters)
                    report.targetedPages += 1
                    report.productsSeen += response.products.count
                    response.products.forEach(take)
                    let isLastPage = response.products.isEmpty || page >= (response.pageCount ?? 1)
                    if isLastPage { break }
                    page += 1
                }
            }
            // 2. Pagine per popolarità fino al tetto per categoria (gli italiani trovati qui restano in cima).
            var page = 1
            while italian.count + others.count < options.perCategory, page <= options.maxPagesPerCategory {
                let response = try await search.search(categoryTag: category.tag, page: page)
                report.pagesFetched += 1
                report.productsSeen += response.products.count
                for dto in response.products where italian.count + others.count < options.perCategory {
                    take(dto)
                }
                let isLastPage = response.products.isEmpty || page >= (response.pageCount ?? 1)
                if isLastPage { break }
                page += 1
            }
            products += italian + others
            report.italianProducts = italian.count
            report.productsSelected = italian.count + others.count
            reports.append(report)
        }

        // Autore della foto: dove la ricerca non lo dà, una richiesta di dettaglio per prodotto (nel rate
        // limit). Un errore qui non fa fallire la costruzione: resta il credito generico ai contributori.
        var creditsRecovered = 0
        for index in products.indices where products[index].image.credit.uploader == OBFMapper.fallbackUploader {
            if let detail = try? await search.product(code: products[index].id),
               let uploader = detail.frontImageUploader {
                products[index].image.credit.uploader = uploader
                creditsRecovered += 1
            }
        }

        let catalog = Catalog(
            schemaVersion: Catalog.currentSchemaVersion,
            generatedAt: now(),
            source: Self.sourceInfo,
            scope: Self.scope,
            products: products
        )
        return AssemblyResult(catalog: catalog, reports: reports, creditsRecovered: creditsRecovered)
    }
}
