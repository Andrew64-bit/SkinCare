import Foundation
import SkinCareKit

/// Traduce un prodotto Open Beauty Facts nel modello del catalogo applicando i criteri di selezione:
/// nome (≥ 3 caratteri), marca, foto frontale e lista ingredienti sono obbligatori; la descrizione è
/// composta dal `DescriptionComposer`; il credito della foto riporta l'autore quando è risolvibile.
public enum OBFMapper {
    public static let photoLicense = "CC BY-SA 3.0"
    public static let fallbackUploader = "contributori Open Beauty Facts"

    public static func map(
        _ dto: OBFProduct, category: CategorySpec, baseURL: URL = OBFClient.defaultBaseURL
    ) -> Product? {
        guard let name = dto.bestName, name.count >= 3,
              let brand = dto.firstBrand,
              let url400 = dto.imageFrontURL,
              let ingredients = dto.bestIngredientsText else {
            return nil
        }
        let composed = DescriptionComposer.compose(
            genericName: dto.italianGenericName,
            categorySingular: category.singular,
            brand: brand,
            quantity: dto.quantity,
            ingredientsText: ingredients
        )
        let sourceURL = baseURL.appending(path: "product/\(dto.code)")
        let product = Product(
            id: dto.code,
            name: name,
            brand: brand,
            category: ProductCategory(id: category.tag, label: category.label),
            quantity: dto.quantity,
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
