import Foundation

/// Risposta di `GET /api/v2/search`.
public struct OBFSearchResponse: Decodable, Sendable {
    public var count: Int
    public var page: Int?
    public var pageCount: Int?
    public var pageSize: Int
    public var products: [OBFProduct]

    enum CodingKeys: String, CodingKey {
        case count, page, products
        case pageCount = "page_count"
        case pageSize = "page_size"
    }
}

/// Risposta di `GET /api/v2/product/{barcode}`.
public struct OBFProductResponse: Decodable, Sendable {
    public var status: Int?
    public var product: OBFProduct?
}

/// Prodotto Open Beauty Facts, con i soli campi usati dal mapper. La decodifica è tollerante: i campi
/// mancanti o di tipo inatteso diventano `nil` invece di far fallire l'intera pagina.
public struct OBFProduct: Decodable, Sendable {
    public var code: String
    public var productName: String?
    public var productNameIt: String?
    public var productNameEn: String?
    public var productNameFr: String?
    public var brands: String?
    public var genericName: String?
    public var genericNameIt: String?
    public var genericNameEn: String?
    public var genericNameFr: String?
    public var quantity: String?
    public var categoriesTags: [String]?
    public var imageFrontURL: URL?
    public var imageFrontSmallURL: URL?
    public var ingredientsText: String?
    public var ingredientsTextIt: String?
    public var ingredientsTextEn: String?
    public var ingredientsTextFr: String?
    public var lang: String?
    public var countriesTags: [String]?
    public var labelsTags: [String]?
    public var lastModifiedT: Int?
    public var uniqueScansN: Int?
    /// Numero di ingredienti riconosciuti dal parser di OBF (assente se il testo non è stato analizzato).
    public var ingredientsN: Int?
    public var unknownIngredientsN: Int?
    public var images: [String: OBFImageEntry]

    enum CodingKeys: String, CodingKey {
        case code, brands, quantity, lang, images
        case productName = "product_name"
        case productNameIt = "product_name_it"
        case productNameEn = "product_name_en"
        case productNameFr = "product_name_fr"
        case genericName = "generic_name"
        case genericNameIt = "generic_name_it"
        case genericNameEn = "generic_name_en"
        case genericNameFr = "generic_name_fr"
        case categoriesTags = "categories_tags"
        case imageFrontURL = "image_front_url"
        case imageFrontSmallURL = "image_front_small_url"
        case ingredientsText = "ingredients_text"
        case ingredientsTextIt = "ingredients_text_it"
        case ingredientsTextEn = "ingredients_text_en"
        case ingredientsTextFr = "ingredients_text_fr"
        case countriesTags = "countries_tags"
        case labelsTags = "labels_tags"
        case lastModifiedT = "last_modified_t"
        case uniqueScansN = "unique_scans_n"
        case ingredientsN = "ingredients_n"
        case unknownIngredientsN = "unknown_ingredients_n"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(LenientString.self, forKey: .code).value
        productName = container.lenientString(.productName)
        productNameIt = container.lenientString(.productNameIt)
        productNameEn = container.lenientString(.productNameEn)
        productNameFr = container.lenientString(.productNameFr)
        brands = container.lenientString(.brands)
        genericName = container.lenientString(.genericName)
        genericNameIt = container.lenientString(.genericNameIt)
        genericNameEn = container.lenientString(.genericNameEn)
        genericNameFr = container.lenientString(.genericNameFr)
        quantity = container.lenientString(.quantity)
        categoriesTags = try? container.decodeIfPresent([String].self, forKey: .categoriesTags)
        imageFrontURL = container.lenientURL(.imageFrontURL)
        imageFrontSmallURL = container.lenientURL(.imageFrontSmallURL)
        ingredientsText = container.lenientString(.ingredientsText)
        ingredientsTextIt = container.lenientString(.ingredientsTextIt)
        ingredientsTextEn = container.lenientString(.ingredientsTextEn)
        ingredientsTextFr = container.lenientString(.ingredientsTextFr)
        lang = container.lenientString(.lang)
        countriesTags = try? container.decodeIfPresent([String].self, forKey: .countriesTags)
        labelsTags = try? container.decodeIfPresent([String].self, forKey: .labelsTags)
        lastModifiedT = (try? container.decodeIfPresent(LenientInt.self, forKey: .lastModifiedT))??.value
        uniqueScansN = (try? container.decodeIfPresent(LenientInt.self, forKey: .uniqueScansN))??.value
        ingredientsN = (try? container.decodeIfPresent(LenientInt.self, forKey: .ingredientsN))??.value
        unknownIngredientsN = (try? container.decodeIfPresent(LenientInt.self, forKey: .unknownIngredientsN))??.value
        images = (try? container.decodeIfPresent(LenientDictionary<OBFImageEntry>.self, forKey: .images))??.values ?? [:]
    }

    // MARK: - Campi derivati

    /// Nome nella lingua migliore per il pubblico italiano, poi il nome principale, poi inglese e francese.
    public var bestName: String? { firstNonEmpty(productNameIt, productName, productNameEn, productNameFr) }
    /// Nome generico solo se è italiano: la descrizione composta deve restare in una sola lingua
    /// (`generic_name` senza suffisso è nella lingua principale del prodotto, usabile solo se `lang == "it"`).
    public var italianGenericName: String? {
        if let genericNameIt { return genericNameIt }
        if lang == "it" { return genericName }
        return nil
    }
    public var bestIngredientsText: String? {
        firstNonEmpty(ingredientsTextIt, ingredientsText, ingredientsTextEn, ingredientsTextFr)
    }
    /// Prima marca dell'elenco separato da virgole ("L'Oréal, L'Oréal Men Expert" → "L'Oréal").
    public var firstBrand: String? {
        brands?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }
    /// Autore della foto frontale: `images["front_xx"].imgid` → `images[imgid].uploader`.
    public var frontImageUploader: String? {
        let frontKeys = images.keys.filter { $0.hasPrefix("front") }.sorted()
        for key in frontKeys {
            if let imgid = images[key]?.imgid, let uploader = images[imgid]?.uploader, !uploader.isEmpty {
                return uploader
            }
        }
        return nil
    }

    private func firstNonEmpty(_ candidates: String?...) -> String? {
        candidates.lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

/// Voce dell'oggetto `images`: le chiavi numeriche portano `uploader`, le chiavi `front_xx`/`ingredients_xx`
/// portano `imgid` e `rev` (a volte stringhe, a volte numeri).
public struct OBFImageEntry: Decodable, Sendable {
    public var uploader: String?
    public var imgid: String?
    public var rev: String?

    enum CodingKeys: String, CodingKey { case uploader, imgid, rev }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uploader = container.lenientString(.uploader)
        imgid = container.lenientString(.imgid)
        rev = container.lenientString(.rev)
    }
}

public enum OBFDecoder {
    public static func searchResponse(from data: Data) throws -> OBFSearchResponse {
        try JSONDecoder().decode(OBFSearchResponse.self, from: data)
    }

    public static func productResponse(from data: Data) throws -> OBFProductResponse {
        try JSONDecoder().decode(OBFProductResponse.self, from: data)
    }

    public static func product(from data: Data) throws -> OBFProduct {
        try JSONDecoder().decode(OBFProduct.self, from: data)
    }
}

// MARK: - Decodifica tollerante

/// Stringa che accetta anche numeri (i barcode e gli `imgid` arrivano in entrambe le forme).
struct LenientString: Decodable {
    var value: String

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "né stringa né numero")
            )
        }
    }
}

struct LenientInt: Decodable {
    var value: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else if let string = try? container.decode(String.self), let int = Int(string) {
            value = int
        } else {
            throw DecodingError.typeMismatch(
                Int.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "non è un intero")
            )
        }
    }
}

/// Dizionario in cui ogni voce viene decodificata singolarmente: una voce malformata viene scartata.
struct LenientDictionary<Value: Decodable>: Decodable {
    var values: [String: Value] = [:]

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        for key in container.allKeys {
            if let value = try? container.decode(Value.self, forKey: key) {
                values[key.stringValue] = value
            }
        }
    }
}

extension KeyedDecodingContainer {
    func lenientString(_ key: Key) -> String? {
        guard let value = (try? decodeIfPresent(LenientString.self, forKey: key))??.value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func lenientURL(_ key: Key) -> URL? {
        guard let string = lenientString(key) else { return nil }
        return URL(string: string)
    }
}
