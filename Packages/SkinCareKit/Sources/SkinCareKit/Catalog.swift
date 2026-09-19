import Foundation

/// Il documento `catalog.json`: un database derivato da Open Beauty Facts (licenza ODbL 1.0).
public struct Catalog: Codable, Sendable, Equatable {
    /// Versione dello schema che questo Kit sa leggere. I documenti con versione maggiore vengono rifiutati.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var source: CatalogSourceInfo
    /// Perimetro dichiarato dal builder (es. «Italia in evidenza: prodotti segnalati in vendita in Italia
    /// in cima, resto dell'UE come riserva»). Opzionale: assente nei documenti v0.1/v0.2.
    public var scope: String?
    public var products: [Product]

    public init(
        schemaVersion: Int, generatedAt: Date, source: CatalogSourceInfo, scope: String? = nil, products: [Product]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.source = source
        self.scope = scope
        self.products = products
    }
}

/// Provenienza e licenza del catalogo (attribuzione richiesta da ODbL/CC BY-SA).
public struct CatalogSourceInfo: Codable, Sendable, Equatable {
    public var name: String
    public var url: URL
    public var license: String
    public var attribution: String

    public init(name: String, url: URL, license: String, attribution: String) {
        self.name = name
        self.url = url
        self.license = license
        self.attribution = attribution
    }
}
