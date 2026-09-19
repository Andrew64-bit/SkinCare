import Foundation

public struct Product: Codable, Sendable, Equatable, Identifiable {
    /// Barcode (EAN/UPC) del prodotto, chiave stabile anche in Open Beauty Facts.
    public var id: String
    public var name: String
    public var brand: String
    public var category: ProductCategory
    public var quantity: String?
    /// Descrizione composta dal builder dai campi strutturati: mai claim di efficacia o medici.
    public var description: String
    public var ingredientsPreview: String?
    public var image: ProductImage
    /// Pagina del prodotto su Open Beauty Facts (attribuzione per prodotto).
    public var sourceURL: URL
    public var lastModified: Date
    /// Segnalato in vendita in Italia (paese di vendita o etichetta in italiano, dai contributori OBF).
    /// Opzionale nel documento: assente → `false`.
    public var soldInItaly: Bool
    /// Paesi di vendita dichiarati (tag OBF senza prefisso, es. «italy»). Opzionale: assente → vuoto.
    public var countries: [String]

    public init(
        id: String,
        name: String,
        brand: String,
        category: ProductCategory,
        quantity: String?,
        description: String,
        ingredientsPreview: String?,
        image: ProductImage,
        sourceURL: URL,
        lastModified: Date,
        soldInItaly: Bool = false,
        countries: [String] = []
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.quantity = quantity
        self.description = description
        self.ingredientsPreview = ingredientsPreview
        self.image = image
        self.sourceURL = sourceURL
        self.lastModified = lastModified
        self.soldInItaly = soldInItaly
        self.countries = countries
    }

    enum CodingKeys: String, CodingKey {
        case id, name, brand, category, quantity, description, ingredientsPreview, image, sourceURL, lastModified
        case soldInItaly, countries
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        category = try container.decode(ProductCategory.self, forKey: .category)
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity)
        description = try container.decode(String.self, forKey: .description)
        ingredientsPreview = try container.decodeIfPresent(String.self, forKey: .ingredientsPreview)
        image = try container.decode(ProductImage.self, forKey: .image)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        soldInItaly = try container.decodeIfPresent(Bool.self, forKey: .soldInItaly) ?? false
        countries = try container.decodeIfPresent([String].self, forKey: .countries) ?? []
    }
}

/// Categoria con etichetta già localizzata nel documento: un'app vecchia mostra correttamente
/// anche categorie aggiunte in seguito dal builder.
public struct ProductCategory: Codable, Sendable, Hashable {
    public var id: String
    public var label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct ProductImage: Codable, Sendable, Equatable {
    public var url400: URL
    public var url200: URL
    public var credit: ImageCredit
    /// Ritaglio del prodotto su sfondo trasparente (400×400 PNG), derivato dalla foto sotto la stessa
    /// licenza CC BY-SA 3.0 e con lo stesso credito. Presente solo se il ritaglio ha superato il cancello.
    public var cutoutURL: URL?

    public init(url400: URL, url200: URL, credit: ImageCredit, cutoutURL: URL? = nil) {
        self.url400 = url400
        self.url200 = url200
        self.credit = credit
        self.cutoutURL = cutoutURL
    }
}

/// Credito della foto (CC BY-SA 3.0): autore e pagina di provenienza.
public struct ImageCredit: Codable, Sendable, Equatable {
    public var uploader: String
    public var license: String
    public var sourceURL: URL

    public init(uploader: String, license: String, sourceURL: URL) {
        self.uploader = uploader
        self.license = license
        self.sourceURL = sourceURL
    }
}
