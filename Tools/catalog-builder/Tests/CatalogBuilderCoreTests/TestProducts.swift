import Foundation
import SkinCareKit

enum TestProducts {
    static func make(id: String) -> Product {
        Product(
            id: id,
            name: "Prodotto \(id)",
            brand: "Marca",
            category: ProductCategory(id: "facial-creams", label: "Creme viso"),
            quantity: "50 ml",
            description: "Crema viso di Marca, 50 ml. Ingredienti principali: Aqua, Glycerin, Parfum, Limonene.",
            ingredientsPreview: "Aqua, Glycerin, Parfum, Limonene",
            image: ProductImage(
                url400: URL(string: "https://images.openbeautyfacts.org/p/\(id)/front.400.jpg")!,
                url200: URL(string: "https://images.openbeautyfacts.org/p/\(id)/front.200.jpg")!,
                credit: ImageCredit(uploader: "tester", license: "CC BY-SA 3.0", sourceURL: URL(string: "https://world.openbeautyfacts.org/product/\(id)")!)
            ),
            sourceURL: URL(string: "https://world.openbeautyfacts.org/product/\(id)")!,
            lastModified: Date(timeIntervalSince1970: 1_780_000_000)
        )
    }
}
