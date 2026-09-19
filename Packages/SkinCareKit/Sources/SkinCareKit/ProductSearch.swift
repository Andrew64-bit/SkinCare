import Foundation

/// Ricerca locale nel catalogo: nome, marca ed etichetta di categoria, senza distinzione di maiuscole e
/// accenti; più parole devono essere tutte presenti (in qualsiasi ordine); una parola di sole cifre
/// cerca anche il barcode per prefisso. Gli ingredienti non sono cercati (troppo rumore).
public enum ProductSearch {
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func terms(in query: String) -> [String] {
        normalize(query).split(separator: " ").map(String.init)
    }

    public static func matches(_ product: Product, query: String) -> Bool {
        let terms = terms(in: query)
        guard !terms.isEmpty else { return true }
        let haystack = normalize("\(product.name) \(product.brand) \(product.category.label)")
        return terms.allSatisfy { term in
            haystack.contains(term) || (term.allSatisfy(\.isNumber) && product.id.hasPrefix(term))
        }
    }

    /// Prodotti che soddisfano la query, nell'ordine del catalogo; query vuota → tutti.
    public static func filter(_ products: [Product], query: String) -> [Product] {
        terms(in: query).isEmpty ? products : products.filter { matches($0, query: query) }
    }
}
