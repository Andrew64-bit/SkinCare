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
        lastModified: Date
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

    public init(url400: URL, url200: URL, credit: ImageCredit) {
        self.url400 = url400
        self.url200 = url200
        self.credit = credit
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
