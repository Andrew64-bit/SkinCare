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

    @Test("bullets and slashes: '•' separates ingredients, ' / ' separates synonyms (first one kept)")
    func bulletsAndSynonyms() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "Garnier", quantity: nil,
            ingredientsText: "AQUA / WATER • COCO-BETAINE • PROPYLENE GLYCOL • SODIUM LAURETH SULFATE • PEG-120"
        )
        #expect(result.ingredientsPreview == "Aqua, Coco-Betaine, Propylene Glycol, Sodium Laureth Sulfate")
    }

    @Test("a leading code or 'INGREDIENTS:' label is stripped")
    func leadingLabelStripped() {
        let coded = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "603258 115 - INGREDIENTS: Aqua, Glycerin, Parfum"
        )
        #expect(coded.ingredientsPreview == "Aqua, Glycerin, Parfum")
        let italian = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "Ingredienti: Aqua, Glycerin"
        )
        #expect(italian.ingredientsPreview == "Aqua, Glycerin")
    }

    @Test("newlines and middle dots also separate ingredients")
    func newlinesSeparate() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "Aqua\nGlycerin · Parfum\r\nLimonene"
        )
        #expect(result.ingredientsPreview == "Aqua, Glycerin, Parfum, Limonene")
    }

    @Test("mixed-case tokens keep their casing")
    func mixedCaseKept() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "Aqua, Butyrospermum Parkii Butter, CI 77891"
        )
        #expect(result.ingredientsPreview == "Aqua, Butyrospermum Parkii Butter, CI 77891")
    }

    @Test("multilingual label prefixes such as '/Ingrediente:/Съставки (INCI):/' are dropped from the first token")
    func multilingualLabelsStripped() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Maschera viso", brand: "Cien", quantity: "17ml",
            ingredientsText: "/Ingrediente:/Ingrediente:/Съставки (INCI):/EvoTariká: Aqua, Glycerin, Kaolin, Parfum, Limonene"
        )
        #expect(result.ingredientsPreview == "Aqua, Glycerin, Kaolin, Parfum")
    }

    @Test("a token that is only a label ('Ingredients:') is dropped, not shown")
    func labelOnlyTokenDropped() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "Ingredients:, Aqua, Glycerin, Parfum"
        )
        #expect(result.ingredientsPreview == "Aqua, Glycerin, Parfum")
    }

    @Test("a leading numeric code ('2050519 10 - Aqua, …') is stripped even without a label")
    func leadingNumericCodeStripped() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "2050519 10 - Aqua, Glycerin, Parfum, Limonene"
        )
        #expect(result.ingredientsPreview == "Aqua, Glycerin, Parfum, Limonene")
    }

    @Test("a period followed by a capitalised word separates ingredients ('Aqua. Glycerin')")
    func periodSeparator() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "Aqua. Glycerin. Alcohol Denat., Parfum"
        )
        #expect(result.ingredientsPreview == "Aqua, Glycerin, Alcohol Denat., Parfum")
    }

    @Test("a two-word slash synonym without spaces keeps the first name; INCI names with a trailing word are kept whole")
    func compactSynonym() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "Aqua/Water, Caprylic/Capric Triglyceride, Parfum/Fragrance, "
                + "Dimethicone/Vinyl Dimethicone Crosspolymer"
        )
        #expect(result.ingredientsPreview
            == "Aqua, Caprylic/Capric Triglyceride, Parfum, Dimethicone/Vinyl Dimethicone Crosspolymer")
    }

    @Test("tokens with stray brackets, degree signs or question marks are dropped")
    func junkTokensDropped() {
        let result = DescriptionComposer.compose(
            genericName: nil, categorySingular: "Crema viso", brand: "X", quantity: nil,
            ingredientsText: "Aqua, ?cerin, Parfum°, Limonene], Linalool, Citral"
        )
        #expect(result.ingredientsPreview == "Aqua, Linalool, Citral")
    }
}
