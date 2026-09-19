import Foundation

/// Categoria del catalogo v1: tag Open Beauty Facts (senza prefisso `en:`), etichetta di sezione e
/// forma singolare per la descrizione composta.
public struct CategorySpec: Sendable, Equatable {
    public let tag: String
    public let label: String
    public let singular: String

    public init(tag: String, label: String, singular: String) {
        self.tag = tag
        self.label = label
        self.singular = singular
    }
}

public enum Categories {
    public static let v1: [CategorySpec] = [
        CategorySpec(tag: "facial-creams", label: "Creme viso", singular: "Crema viso"),
        CategorySpec(tag: "cleansers", label: "Detergenti", singular: "Detergente"),
        CategorySpec(tag: "sunscreen", label: "Solari", singular: "Protezione solare"),
        CategorySpec(tag: "face-masks", label: "Maschere viso", singular: "Maschera viso"),
        CategorySpec(tag: "anti-aging-face-care-products", label: "Anti-età", singular: "Trattamento viso anti-età"),
        CategorySpec(tag: "lip-balms", label: "Balsami labbra", singular: "Balsamo labbra")
    ]
}
