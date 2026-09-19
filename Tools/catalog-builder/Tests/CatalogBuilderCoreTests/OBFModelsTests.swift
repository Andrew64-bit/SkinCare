import Foundation
import Testing
@testable import CatalogBuilderCore

@Suite("Open Beauty Facts DTOs (real fixtures)")
struct OBFModelsTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test("a search page decodes with count, page size and 100 products")
    func searchPageDecodes() throws {
        let response = try OBFDecoder.searchResponse(from: fixture("search_facial_creams_page1"))
        #expect(response.count == 465)
        #expect(response.pageSize == 100)
        #expect(response.products.count == 100)
    }

    @Test("a known product exposes the fields the mapper needs")
    func knownProductFields() throws {
        let response = try OBFDecoder.searchResponse(from: fixture("search_facial_creams_page1"))
        let nivea = try #require(response.products.first { $0.code == "4005800001192" })
        #expect(nivea.brands == "Nivea")
        #expect(nivea.quantity == "150 ml")
        #expect(nivea.imageFrontURL?.absoluteString.hasSuffix(".400.jpg") == true)
        #expect(nivea.uniqueScansN == 59)
        #expect(nivea.lastModifiedT != nil)
        #expect(nivea.bestIngredientsText?.isEmpty == false)
        #expect(nivea.ingredientsN == 22)
    }

    @Test("the front image uploader is resolved through images[front_xx].imgid → images[imgid].uploader")
    func uploaderResolution() throws {
        let response = try OBFDecoder.productResponse(from: fixture("product_8001120704788"))
        let product = try #require(response.product)
        #expect(product.frontImageUploader == "gla01")
    }

    @Test("a malformed entry inside `images` does not break the product")
    func lenientImages() throws {
        let json = """
        {"code":"1","product_name":"X","images":{"1":{"uploader":"u1"},"front_it":{"imgid":1,"rev":"3"},"broken":"oops"}}
        """
        let product = try OBFDecoder.product(from: Data(json.utf8))
        #expect(product.frontImageUploader == "u1")
    }

    @Test("the uploader is taken from the front image of the same language as the image URL, not the first key")
    func uploaderFollowsImageLanguage() throws {
        let json = """
        {"code":"1","product_name":"X","image_front_url":"https://images.openbeautyfacts.org/images/products/000/front_fr.3.400.jpg",
         "images":{"1":{"uploader":"arabic-uploader"},"2":{"uploader":"french-uploader"},
                   "front_ar":{"imgid":"1","rev":"5"},"front_fr":{"imgid":"2","rev":"3"}}}
        """
        let product = try OBFDecoder.product(from: Data(json.utf8))
        #expect(product.frontImageUploader == "french-uploader")
    }
}
