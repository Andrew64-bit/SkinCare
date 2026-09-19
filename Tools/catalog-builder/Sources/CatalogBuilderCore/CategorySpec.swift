import Foundation

/// Categoria del catalogo v1: tag Open Beauty Facts (senza prefisso `en:`), etichetta di sezione e
/// forma singolare per la descrizione composta.
public struct CategorySpec: Sendable, Equatable {
    public let tag: String
    public let label: String
    public let singular: String
    /// Parole (minuscole, senza accenti) che nel nome rivelano un prodotto di altro tipo finito nella categoria.
    public let excludedNameKeywords: [String]

    public init(tag: String, label: String, singular: String, excludedNameKeywords: [String] = []) {
        self.tag = tag
        self.label = label
        self.singular = singular
        self.excludedNameKeywords = excludedNameKeywords
    }
}

public enum Categories {
    public static let v1: [CategorySpec] = [
        CategorySpec(tag: "facial-creams", label: "Creme viso", singular: "Crema viso"),
        CategorySpec(
            tag: "cleansers", label: "Detergenti", singular: "Detergente",
            excludedNameKeywords: ["acetone", "dissolvant", "solvente", "unghie", "nail", "vernis", "smalto"]
        ),
        CategorySpec(tag: "sunscreen", label: "Solari", singular: "Protezione solare"),
        CategorySpec(tag: "face-masks", label: "Maschere viso", singular: "Maschera viso"),
        CategorySpec(
            tag: "anti-aging-face-care-products", label: "Anti-età", singular: "Trattamento viso anti-età",
            excludedNameKeywords: ["savon", "sapone", "soap", "seife", "jabon"]
        ),
        CategorySpec(tag: "lip-balms", label: "Balsami labbra", singular: "Balsamo labbra"),
        CategorySpec(tag: "hand-creams", label: "Creme mani", singular: "Crema mani"),
        CategorySpec(tag: "micellar-waters", label: "Acque micellari", singular: "Acqua micellare")
    ]
}
