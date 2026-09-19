import Foundation
import SkinCareKit

/// Traduce un prodotto Open Beauty Facts nel modello del catalogo applicando i criteri di selezione:
/// nome (≥ 3 caratteri), marca, foto frontale e lista ingredienti sono obbligatori; la descrizione è
/// composta dal `DescriptionComposer`; il credito della foto riporta l'autore quando è risolvibile.
public enum OBFMapper {
    public static let photoLicense = "CC BY-SA 3.0"
    public static let fallbackUploader = "contributori Open Beauty Facts"
    /// Una lista INCI reale ha molti ingredienti: sotto questa soglia il testo non è una lista utilizzabile.
    public static let minimumIngredientTokens = 5

    /// Plausibilità della lista ingredienti: almeno 5 token, uno dei primi 4 è un ingrediente cosmetico
    /// noto, e se OBF ha contato gli ingredienti ne ha trovati almeno 5. Scarta indirizzi, codici,
    /// liste di alimenti finite sotto una categoria cosmetica e testi OCR inutilizzabili.
    static func isPlausibleIngredientList(_ text: String, ingredientsN: Int?) -> Bool {
        if let ingredientsN, ingredientsN < minimumIngredientTokens { return false }
        let tokens = DescriptionComposer.ingredientTokens(from: text, max: 12)
        guard tokens.count >= minimumIngredientTokens else { return false }
        return tokens.prefix(4).contains { INCIVocabulary.isKnown($0) }
    }

    /// Nome con almeno 3 caratteri e una lettera latina, e diverso dal barcode.
    static func isPlausibleName(_ name: String, code: String) -> Bool {
        name.count >= 3 && name != code && name.range(of: "[A-Za-z]", options: .regularExpression) != nil
    }

    private static let quantityPattern = try? NSRegularExpression(
        pattern: #"^\s*(\d+(?:[.,]\d+)?)\s*(ml|mL|ML|cl|cL|l|L|g|gr|G|kg|oz|fl\.?\s?oz)\b"#
    )

    /// «473ml - Normale…» → «473 ml»; senza unità riconoscibile all'inizio → nil (meglio niente che sporco).
    static func sanitizedQuantity(_ raw: String?) -> String? {
        guard let raw, let quantityPattern else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = quantityPattern.firstMatch(in: raw, range: range),
              let number = Range(match.range(at: 1), in: raw),
              let unit = Range(match.range(at: 2), in: raw) else { return nil }
        return "\(raw[number]) \(raw[unit])"
    }

    public static func map(
        _ dto: OBFProduct, category: CategorySpec, baseURL: URL = OBFClient.defaultBaseURL
    ) -> Product? {
        guard let name = dto.bestName, isPlausibleName(name, code: dto.code),
              let brand = dto.firstBrand,
              let url400 = dto.imageFrontURL,
              let ingredients = dto.bestIngredientsText,
              isPlausibleIngredientList(ingredients, ingredientsN: dto.ingredientsN) else {
            return nil
        }
        let quantity = sanitizedQuantity(dto.quantity)
        let composed = DescriptionComposer.compose(
            genericName: dto.italianGenericName,
            categorySingular: category.singular,
            brand: brand,
            quantity: quantity,
            ingredientsText: ingredients
        )
        let sourceURL = baseURL.appending(path: "product/\(dto.code)")
        let product = Product(
            id: dto.code,
            name: name,
            brand: brand,
            category: ProductCategory(id: category.tag, label: category.label),
            quantity: quantity,
            description: composed.description,
            ingredientsPreview: composed.ingredientsPreview,
            image: ProductImage(
                url400: url400,
                url200: dto.imageFrontSmallURL ?? derivedSmallImageURL(from: url400),
                credit: ImageCredit(
                    uploader: dto.frontImageUploader ?? fallbackUploader,
                    license: photoLicense,
                    sourceURL: sourceURL
                )
            ),
            sourceURL: sourceURL,
            lastModified: Date(timeIntervalSince1970: TimeInterval(dto.lastModifiedT ?? 0))
        )
        return CatalogCodec.isValid(product) ? product : nil
    }

    /// Le immagini OBF esistono nelle taglie 100/200/400/full con lo stesso nome: `.400.` → `.200.`.
    static func derivedSmallImageURL(from url: URL) -> URL {
        let string = url.absoluteString
        guard let range = string.range(of: ".400.", options: .backwards) else { return url }
        return URL(string: string.replacingCharacters(in: range, with: ".200.")) ?? url
    }
}
