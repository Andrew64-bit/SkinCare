import Foundation
import Testing
import SkinCareKit
@testable import CatalogBuilderCore

@Suite("OBF → Product mapper")
struct OBFMapperTests {
    private let facialCreams = Categories.v1[0]

    private func fixtureProducts() throws -> [OBFProduct] {
        let url = try #require(Bundle.module.url(
            forResource: "search_facial_creams_page1", withExtension: "json", subdirectory: "Fixtures"
        ))
        return try OBFDecoder.searchResponse(from: Data(contentsOf: url)).products
    }

    private func product(_ code: String) throws -> OBFProduct {
        try #require(fixtureProducts().first { $0.code == code })
    }

    @Test("Nivea Creme maps to a complete product")
    func niveaMaps() throws {
        let mapped = try #require(OBFMapper.map(product("4005800001192"), category: facialCreams))
        #expect(mapped.id == "4005800001192")
        #expect(mapped.brand == "Nivea")
        #expect(mapped.quantity == "150 ml")
        #expect(mapped.category == ProductCategory(id: "facial-creams", label: "Creme viso"))
        #expect(mapped.description.hasPrefix("Crema viso di Nivea, 150 ml. Ingredienti principali: "))
        #expect(mapped.image.url400.absoluteString.hasSuffix(".400.jpg"))
        #expect(mapped.image.url200.absoluteString.hasSuffix(".200.jpg"))
        #expect(mapped.image.credit.license == "CC BY-SA 3.0")
        #expect(!mapped.image.credit.uploader.isEmpty)
        #expect(mapped.sourceURL.absoluteString == "https://world.openbeautyfacts.org/product/4005800001192")
        #expect(mapped.image.credit.sourceURL == mapped.sourceURL)
        #expect(mapped.lastModified > Date(timeIntervalSince1970: 1_600_000_000))
    }

    @Test("a generic name in another language is ignored: the description stays in Italian")
    func foreignGenericNameIgnored() throws {
        let json = """
        {"code":"1","product_name":"Crème","brands":"B","lang":"fr","generic_name":"Crème hydratante visage",
         "ingredients_text":"Aqua, Glycerin","image_front_url":"https://images.openbeautyfacts.org/a/front.400.jpg"}
        """
        let mapped = try #require(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams))
        #expect(mapped.description.hasPrefix("Crema viso di B. Ingredienti principali: Aqua, Glycerin."))
    }

    @Test("an Italian generic name replaces the category sentence")
    func italianGenericNameUsed() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B","generic_name_it":"crema idratante viso",
         "ingredients_text":"Aqua, Glycerin","image_front_url":"https://images.openbeautyfacts.org/a/front.400.jpg"}
        """
        let mapped = try #require(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams))
        #expect(mapped.description.hasPrefix("Crema idratante viso. Ingredienti principali: Aqua, Glycerin."))
    }

    @Test("only the first brand of a comma-separated list is used")
    func firstBrandOnly() throws {
        let mapped = try #require(OBFMapper.map(product("3600520297118"), category: facialCreams))
        #expect(mapped.brand == "L'Oréal")
    }

    @Test("a product without ingredients is not selected")
    func noIngredientsRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B","image_front_url":"https://images.openbeautyfacts.org/a/front.400.jpg"}
        """
        #expect(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams) == nil)
    }

    @Test("a product whose ingredient list yields fewer than 2 tokens is not selected")
    func tooFewIngredientTokensRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B","ingredients_text":"Aqua",
         "image_front_url":"https://images.openbeautyfacts.org/a/front.400.jpg"}
        """
        #expect(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams) == nil)
    }

    @Test("a product without brand is not selected")
    func noBrandRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","ingredients_text":"Aqua, Glycerin",
         "image_front_url":"https://images.openbeautyfacts.org/a/front.400.jpg"}
        """
        #expect(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams) == nil)
    }

    @Test("a product without a front image is not selected")
    func noImageRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B","ingredients_text":"Aqua, Glycerin"}
        """
        #expect(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams) == nil)
    }

    @Test("the 200 px URL is derived from the 400 px one when the small variant is missing")
    func derivesSmallImage() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B","ingredients_text":"Aqua, Glycerin",
         "image_front_url":"https://images.openbeautyfacts.org/images/products/000/front_it.3.400.jpg"}
        """
        let mapped = try #require(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams))
        #expect(mapped.image.url200.absoluteString == "https://images.openbeautyfacts.org/images/products/000/front_it.3.200.jpg")
    }

    @Test("most fixture products with name, brand, image and ingredients map successfully")
    func fixtureYield() throws {
        let mapped = try fixtureProducts().compactMap { OBFMapper.map($0, category: facialCreams) }
        #expect(mapped.count >= 60)
    }
}
