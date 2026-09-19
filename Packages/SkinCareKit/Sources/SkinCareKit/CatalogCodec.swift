import Foundation

/// Serializzazione del catalogo: JSON ordinato e leggibile (diff puliti in git), date ISO 8601.
/// In lettura applica le regole di validità: schema compatibile, prodotti strutturalmente validi,
/// nessun duplicato, numero minimo di prodotti. I prodotti invalidi vengono scartati (resilienza a un
/// errore del builder su pochi item); sotto la soglia il documento intero viene rifiutato.
public enum CatalogCodec {
    public static func encode(_ catalog: Catalog) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(catalog)
    }

    public static func decode(_ data: Data, minimumProducts: Int) throws -> Catalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw CatalogError.corruptData(String(describing: error))
        }
        guard probe.schemaVersion >= 1, probe.schemaVersion <= Catalog.currentSchemaVersion else {
            throw CatalogError.unsupportedSchema(probe.schemaVersion)
        }

        let catalog: Catalog
        do {
            catalog = try decoder.decode(Catalog.self, from: data)
        } catch {
            throw CatalogError.corruptData(String(describing: error))
        }
        return try validated(catalog, minimumProducts: minimumProducts)
    }

    /// Soglia predefinita sotto la quale un catalogo non viene accettato (né dal remoto né dallo store).
    public static let defaultMinimumProducts = 50

    /// Applica le regole di validità a un catalogo già decodificato.
    public static func validated(_ catalog: Catalog, minimumProducts: Int) throws -> Catalog {
        guard catalog.schemaVersion >= 1, catalog.schemaVersion <= Catalog.currentSchemaVersion else {
            throw CatalogError.unsupportedSchema(catalog.schemaVersion)
        }
        var result = catalog
        result.products = validProducts(in: catalog.products)
        guard result.products.count >= minimumProducts else {
            throw CatalogError.tooFewProducts(valid: result.products.count, minimum: minimumProducts)
        }
        return result
    }

    /// Prodotti strutturalmente validi, senza duplicati (vince la prima occorrenza), nell'ordine originale.
    static func validProducts(in products: [Product]) -> [Product] {
        var seen = Set<String>()
        return products.filter { product in
            guard isValid(product), !seen.contains(product.id) else { return false }
            seen.insert(product.id)
            return true
        }
    }

    public static func isValid(_ product: Product) -> Bool {
        let name = product.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = product.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = product.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return !product.id.isEmpty
            && name.count >= 3
            && !brand.isEmpty
            && !description.isEmpty
            && isSecure(product.image.url200)
            && isSecure(product.image.url400)
            && isSecure(product.sourceURL)
            && (product.image.cutoutURL.map(isSecure) ?? true)
    }

    private static func isSecure(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && !(url.host() ?? "").isEmpty
    }

    private struct SchemaProbe: Decodable {
        var schemaVersion: Int
    }
}
