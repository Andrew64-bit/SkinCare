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

    // MARK: - Round 3 (P5)

    private let inci5 = "\"ingredients_text\":\"Aqua, Glycerin, Parfum, Limonene, Linalool\""

    @Test("a list whose first token is a 110-character glued run is rejected (preview must start at ingredient 1)")
    func gluedFirstTokenRejected() throws {
        let glued = String(repeating: "Aqua Glycerin Paraffinum Liquidum ", count: 4)
        let json = """
        {"code":"1","product_name":"Crema","brands":"B",\(image),
         "ingredients_text":"\(glued), Cera Microcristallina, Panthenol, Parfum, Limonene, Linalool"}
        """
        #expect(try mapped(json) == nil)
    }

    @Test("a list with only one known ingredient among the first four is rejected")
    func oneKnownAmongFourRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B",\(image),
         "ingredients_text":"Aqua, Zorbium Extractum, Frobnicate Dust, Quux Powder, Glycerin, Parfum"}
        """
        #expect(try mapped(json) == nil)
    }

    @Test("brands in all caps or all lowercase are capitalised per word, hyphens included")
    func brandCaseNormalised() throws {
        func brand(_ raw: String) throws -> String? {
            try mapped("{\"code\":\"1\",\"product_name\":\"Crema\",\"brands\":\"\(raw)\",\(image),\(inci5)}")?.brand
        }
        #expect(try brand("NIVEA") == "Nivea")
        #expect(try brand("neutrogena") == "Neutrogena")
        #expect(try brand("LA ROCHE-POSAY") == "La Roche-Posay")
        #expect(try brand("La-roche-posay") == "La-Roche-Posay")
        #expect(try brand("CeraVe") == "CeraVe")
        #expect(try brand("L'Oréal Paris") == "L'Oréal Paris")
    }

    @Test("quantity units are normalised: gr → g, mL/ML → ml, l → L")
    func quantityUnitsNormalised() throws {
        func quantity(_ raw: String) throws -> String? {
            let json = "{\"code\":\"1\",\"product_name\":\"Crema\",\"brands\":\"B\",\(image),\(inci5),\"quantity\":\"\(raw)\"}"
            return try mapped(json)?.quantity
        }
        #expect(try quantity("28 gr") == "28 g")
        #expect(try quantity("200 mL") == "200 ml")
        #expect(try quantity("1 l") == "1 L")
        #expect(try quantity("4,7 ml") == "4,7 ml")
    }

    @Test("products whose name reveals another kind of product are excluded from the category")
    func categoryExclusions() throws {
        let cleansers = Categories.v1[1]
        let antiAging = Categories.v1[4]
        func name(_ raw: String, in category: CategorySpec) throws -> Product? {
            let json = "{\"code\":\"1\",\"product_name\":\"\(raw)\",\"brands\":\"B\",\(image),\(inci5)}"
            return OBFMapper.map(try OBFDecoder.product(from: Data(json.utf8)), category: category)
        }
        #expect(try name("Dissolvant express acétone", in: cleansers) == nil)
        #expect(try name("Solvente per unghie", in: cleansers) == nil)
        #expect(try name("Savon surgras", in: antiAging) == nil)
        #expect(try name("Gel nettoyant purifiant", in: cleansers) != nil)
    }

    @Test("a token with non-Latin letters among the first four (Cyrillic 'Аqua') rejects the product")
    func nonLatinTokenRejected() throws {
        let json = """
        {"code":"1","product_name":"Crema","brands":"B",\(image),
         "ingredients_text":"Аqua, Glycerin, Parfum, Limonene, Linalool, Citral"}
        """
        #expect(try mapped(json) == nil)
    }

    @Test("accented Latin ingredient names are still accepted")
    func accentedLatinAccepted() throws {
        let json = """
        {"code":"1","product_name":"Crème","brands":"B",\(image),
         "ingredients_text":"Eau, glycérine, palmitate d'isopropyle, alcool cétéarylique, parfum, limonène"}
        """
        #expect(try mapped(json) != nil)
    }
}
