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
         "ingredients_text":"Aqua, Glycerin, Alcohol Denat., Parfum, Limonene",
          "image_front_url":"https://images.openbeautyfacts.org/a/front.400.jpg"}
        """
        let mapped = try #require(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams))
        let expected = "Crema viso di B. Ingredienti principali: Aqua, Glycerin, Alcohol Denat., Parfum."
        #expect(mapped.description.hasPrefix(expected))
    }

    @Test("an Italian generic name replaces the category sentence")
    func italianGenericNameUsed() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B","generic_name_it":"crema idratante viso",
         "ingredients_text":"Aqua, Glycerin, Alcohol Denat., Parfum, Limonene",
          "image_front_url":"https://images.openbeautyfacts.org/a/front.400.jpg"}
        """
        let mapped = try #require(OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams))
        let expected = "Crema idratante viso. Ingredienti principali: Aqua, Glycerin, Alcohol Denat., Parfum."
        #expect(mapped.description.hasPrefix(expected))
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
        {"code":"1","product_name":"Crema","ingredients_text":"Aqua, Glycerin, Alcohol Denat., Parfum, Limonene",
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
        {"code":"1","product_name":"Crema","brands":"B","ingredients_text":"Aqua, Glycerin, Alcohol Denat., Parfum, Limonene",
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

    private func mapped(_ json: String) throws -> Product? {
        OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: facialCreams)
    }

    private let image = "\"image_front_url\":\"https://images.openbeautyfacts.org/a/front.400.jpg\""

    @Test("an ingredient text that is not a cosmetic INCI list (an address) is rejected")
    func addressRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B",\(image),
         "ingredients_text":"Carl-Friedrich-Gauss-Str. 2, DE-50259 Pulheim, Germany, Tel. 02238, Fax 02238"}
        """
        #expect(try mapped(json) == nil)
    }

    @Test("a food ingredient list under a cosmetic category is rejected")
    func foodListRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B",\(image),
         "ingredients_text":"cultured pasteurized part-skim milk, cheese cultures, salt, enzymes, annatto"}
        """
        #expect(try mapped(json) == nil)
    }

    @Test("fewer than 5 ingredient tokens is rejected")
    func fewTokensRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B",\(image),"ingredients_text":"Aqua, Glycerin, Parfum"}
        """
        #expect(try mapped(json) == nil)
    }

    @Test("ingredients_n below 5 reported by OBF is rejected even if the text has tokens")
    func lowIngredientsNRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B",\(image),"ingredients_n":2,
         "ingredients_text":"Aqua, Glycerin, Parfum, Limonene, Linalool, Citral"}
        """
        #expect(try mapped(json) == nil)
    }

    @Test("a real INCI list in French passes the plausibility check")
    func frenchListAccepted() throws {
        let json = """
        {"code":"1","product_name":"Crème","brands":"B",\(image),
         "ingredients_text":"Eau, glycérine, palmitate d'isopropyle, alcool cétéarylique, parfum, limonène"}
        """
        #expect(try mapped(json) != nil)
    }

    @Test("a name without Latin letters or equal to the barcode is rejected")
    func nameWithoutLettersRejected() throws {
        let inci = "\"ingredients_text\":\"Aqua, Glycerin, Parfum, Limonene, Linalool\""
        let cyrillic = "{\"code\":\"1\",\"product_name\":\"Крем для лица\",\"brands\":\"B\",\(image),\(inci)}"
        let barcode = "{\"code\":\"3606000537750\",\"product_name\":\"3606000537750\",\"brands\":\"B\",\(image),\(inci)}"
        #expect(try mapped(cyrillic) == nil)
        #expect(try mapped(barcode) == nil)
    }

    @Test("quantities are normalised to '<number> <unit>' or dropped when unparseable")
    func quantitySanitised() throws {
        let inci = "\"ingredients_text\":\"Aqua, Glycerin, Parfum, Limonene, Linalool\""
        func quantity(_ raw: String) throws -> String? {
            let json = "{\"code\":\"1\",\"product_name\":\"Crema\",\"brands\":\"B\",\(image),\(inci),\"quantity\":\"\(raw)\"}"
            return try mapped(json)?.quantity
        }
        #expect(try quantity("473ml - Normale tot droge huid") == "473 ml")
        #expect(try quantity("150 ml") == "150 ml")
        #expect(try quantity("50") == nil)
        #expect(try quantity("7 x 1.3 ml ml") == nil)
        #expect(try quantity("30mk") == nil)
        #expect(try quantity("1,5 L") == "1,5 L")
    }
}
