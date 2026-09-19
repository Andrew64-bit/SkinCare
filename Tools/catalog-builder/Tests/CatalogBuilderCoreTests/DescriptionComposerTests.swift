import Foundation
import Testing
@testable import CatalogBuilderCore

@Suite("Description composer")
struct DescriptionComposerTests {
    private let inci = "Aqua, Glycerin, Paraffinum Liquidum, Cera Microcristallina, Glyceryl Stearate, Parfum"

    @Test("without a generic name: category + brand + quantity, then the first 4 ingredients")
    func categoryAndBrand() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "Nivea", quantity: "150 ml", ingredientsText: inci
        )
        #expect(result.description ==
            "Crema viso di Nivea, 150 ml. Ingredienti principali: Aqua, Glycerin, Paraffinum Liquidum, Cera Microcristallina.")
        #expect(result.ingredientsPreview == "Aqua, Glycerin, Paraffinum Liquidum, Cera Microcristallina")
    }

    @Test("with a generic name it replaces the category sentence")
    func genericName() {
        let result = DescriptionComposer.compose(
            genericName: "crema multiuso per viso, corpo e mani.", categorySingular: "Crema viso", brand: "Stanhome",
            quantity: "250 ml", ingredientsText: inci
        )
        #expect(result.description.hasPrefix("Crema multiuso per viso, corpo e mani, 250 ml. Ingredienti principali: Aqua"))
    }

    @Test("without quantity the sentence closes right after the brand")
    func noQuantity() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Detergente", brand: "CeraVe", quantity: nil, ingredientsText: inci
        )
        #expect(result.description.hasPrefix("Detergente di CeraVe. Ingredienti principali: Aqua"))
    }

    @Test("ingredient tokens are split on commas and semicolons, trimmed, and stripped of asterisks")
    func ingredientCleanup() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "Bio", quantity: nil,
            ingredientsText: " Aqua ,Glycerin;  Alcohol Denat. , *Parfum (Fragrance)*, Limonene "
        )
        #expect(result.ingredientsPreview == "Aqua, Glycerin, Alcohol Denat., Parfum (Fragrance)")
    }

    @Test("without ingredients the preview is nil and the description has no ingredient sentence")
    func noIngredients() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Solare", brand: "Avène", quantity: "50 ml", ingredientsText: "  "
        )
        #expect(result.description == "Solare di Avène, 50 ml.")
        #expect(result.ingredientsPreview == nil)
    }

    @Test("a generic name longer than 80 characters or ending with '!' is not used")
    func genericNameSanitised() {
        let shouting = DescriptionComposer.compose(
            genericName: "La migliore crema del mondo!", categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: inci
        )
        #expect(shouting.description.hasPrefix("Crema viso di X."))
        let tooLong = DescriptionComposer.compose(
            genericName: String(repeating: "a", count: 81), categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: inci
        )
        #expect(tooLong.description.hasPrefix("Crema viso di X."))
    }
}
