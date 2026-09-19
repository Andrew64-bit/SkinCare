import Foundation
import Testing
@testable import SkinCareKit

@Suite("Product search")
struct ProductSearchTests {
    private func product(_ id: String, name: String, brand: String, category: String = "Creme viso",
                         ingredients: String = "Aqua, Glycerin") -> Product {
        var product = TestCatalogs.product(index: 0, category: ProductCategory(id: category.lowercased(), label: category))
        product.id = id
        product.name = name
        product.brand = brand
        product.ingredientsPreview = ingredients
        product.description = "\(category) di \(brand). Ingredienti principali: \(ingredients)."
        return product
    }

    private var catalog: [Product] {
        [
            product("4005800001192", name: "Nivea Creme", brand: "Nivea"),
            product("3600551020419", name: "La Crème des peaux extra-sèches", brand: "Mixa"),
            product("3574661287201", name: "Hydro Boost Aqua-Gel", brand: "Neutrogena"),
            product("3282770396317", name: "Spray Enfant 50+", brand: "Avène", category: "Solari")
        ]
    }

    @Test("an empty or blank query returns every product in the same order")
    func emptyQuery() {
        #expect(ProductSearch.filter(catalog, query: "") == catalog)
        #expect(ProductSearch.filter(catalog, query: "   ") == catalog)
    }

    @Test("matching ignores case")
    func caseInsensitive() {
        #expect(ProductSearch.filter(catalog, query: "NIVEA").map(\.id) == ["4005800001192"])
    }

    @Test("matching ignores accents in both directions")
    func diacriticsInsensitive() {
        #expect(ProductSearch.filter(catalog, query: "creme des peaux").map(\.id) == ["3600551020419"])
        #expect(ProductSearch.filter(catalog, query: "Avene").map(\.id) == ["3282770396317"])
    }

    @Test("the brand is searched")
    func brand() {
        #expect(ProductSearch.filter(catalog, query: "neutro").map(\.id) == ["3574661287201"])
    }

    @Test("the category label is searched")
    func category() {
        #expect(ProductSearch.filter(catalog, query: "solari").map(\.id) == ["3282770396317"])
    }

    @Test("several words must all match (AND), in any order")
    func multiWord() {
        #expect(ProductSearch.filter(catalog, query: "creme nivea").map(\.id) == ["4005800001192"])
        #expect(ProductSearch.filter(catalog, query: "nivea gel").isEmpty)
    }

    @Test("digits match the barcode by prefix")
    func barcodePrefix() {
        #expect(ProductSearch.filter(catalog, query: "40058").map(\.id) == ["4005800001192"])
    }

    @Test("ingredients are not searched")
    func ingredientsIgnored() {
        #expect(ProductSearch.filter(catalog, query: "glycerin").isEmpty)
    }

    @Test("results keep the catalog order")
    func orderPreserved() {
        // «e» compare in tutti e quattro: l'ordine deve restare quello del catalogo
        #expect(ProductSearch.filter(catalog, query: "e").map(\.id) == catalog.map(\.id))
    }

    @Test("normalize lowercases, strips accents and collapses whitespace")
    func normalizeFunction() {
        #expect(ProductSearch.normalize("  Crème   Hydratante ") == "creme hydratante")
    }
}
