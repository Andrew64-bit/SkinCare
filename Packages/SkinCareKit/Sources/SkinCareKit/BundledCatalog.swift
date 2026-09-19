import Foundation

/// Snapshot del catalogo incluso nel Kit (`Resources/catalog.json`, generato da `catalog-builder`).
/// È la rete di sicurezza: primo avvio, assenza di rete, store corrotto.
public enum BundledCatalog {
    public static func load() throws -> Catalog {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.corruptData("catalog.json assente dal bundle")
        }
        let data = try Data(contentsOf: url)
        return try CatalogCodec.decode(data, minimumProducts: CatalogCodec.defaultMinimumProducts)
    }
}
