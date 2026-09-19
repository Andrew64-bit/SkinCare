import Foundation
import Synchronization
import Testing
import SkinCareKit
@testable import CatalogBuilderCore

/// Scaricatore finto: restituisce byte fissi e registra le URL richieste.
final class FakeImageFetcher: ImageFetching {
    let requests = Mutex<[URL]>([])
    func fetch(_ url: URL) async throws -> Data {
        requests.withLock { $0.append(url) }
        return Data("image-bytes-\(url.absoluteString)".utf8)
    }
}

/// Elaboratore finto: il verdetto dipende dal barcode contenuto nell'URL (…/hand/… → mano).
struct FakeProcessor: CutoutProcessing {
    func process(imageData: Data) throws -> CutoutResult {
        let text = String(bytes: imageData, encoding: .utf8) ?? ""
        if text.contains("hand") { return CutoutResult(verdict: .hand, coverage: 0.5, personShare: 0.6, png: nil) }
        return CutoutResult(verdict: .clean, coverage: 0.5, personShare: 0, png: Data("png-\(text)".utf8))
    }
}

@Suite("Cutout pipeline")
struct CutoutPipelineTests {
    private let baseURL = URL(string: "https://andrew64-bit.github.io/SkinCare/images/")!

    private func makeDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "cutout-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func product(_ id: String, image: String) -> Product {
        var product = TestProducts.make(id: id)
        product.image.url400 = URL(string: "https://images.openbeautyfacts.org/p/\(image)/front.400.jpg")!
        return product
    }

    @Test("clean cutouts are written as <barcode>.png, linked in the catalog and recorded in the manifest")
    func writesAndLinks() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fetcher = FakeImageFetcher()
        let pipeline = CutoutPipeline(
            directory: dir, baseURL: baseURL, fetcher: fetcher, processor: FakeProcessor(), minimumInterval: 0
        )
        let products = [product("1", image: "one"), product("2", image: "hand-two")]
        let outcome = try await pipeline.run(products: products)
        #expect(outcome.products[0].image.cutoutURL == baseURL.appending(path: "1.png"))
        #expect(outcome.products[1].image.cutoutURL == nil)
        #expect(FileManager.default.fileExists(atPath: dir.appending(path: "1.png").path()))
        #expect(!FileManager.default.fileExists(atPath: dir.appending(path: "2.png").path()))
        #expect(outcome.summary.clean == 1 && outcome.summary.hand == 1 && outcome.summary.processed == 2)
        let manifest = try CutoutManifest.load(from: dir)
        #expect(manifest.entries["1"]?.verdict == .clean)
        #expect(manifest.entries["2"]?.verdict == .hand)
        #expect(manifest.entries["1"]?.sourceURL == products[0].image.url400)
    }

    @Test("a product whose source image is unchanged is not downloaded again, but keeps its link")
    func incremental() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fetcher = FakeImageFetcher()
        let pipeline = CutoutPipeline(
            directory: dir, baseURL: baseURL, fetcher: fetcher, processor: FakeProcessor(), minimumInterval: 0
        )
        _ = try await pipeline.run(products: [product("1", image: "one"), product("2", image: "hand-two")])
        let second = try await pipeline.run(products: [product("1", image: "one"), product("2", image: "hand-two")])
        #expect(fetcher.requests.withLock { $0.count } == 2, "nessun nuovo download")
        #expect(second.products[0].image.cutoutURL == baseURL.appending(path: "1.png"))
        #expect(second.products[1].image.cutoutURL == nil)
        #expect(second.summary.processed == 0 && second.summary.reused == 2)
    }

    @Test("a changed source image (new OBF revision) is processed again")
    func reprocessOnChange() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fetcher = FakeImageFetcher()
        let pipeline = CutoutPipeline(
            directory: dir, baseURL: baseURL, fetcher: fetcher, processor: FakeProcessor(), minimumInterval: 0
        )
        _ = try await pipeline.run(products: [product("1", image: "one")])
        let outcome = try await pipeline.run(products: [product("1", image: "one-rev2")])
        #expect(fetcher.requests.withLock { $0.count } == 2, "un download per corsa: la revisione è cambiata")
        #expect(outcome.summary.processed == 1)
        #expect(outcome.products[0].image.cutoutURL == baseURL.appending(path: "1.png"))
    }

    @Test("a download failure leaves the product without cutout and does not stop the run")
    func downloadFailureIsTolerated() async throws {
        struct FailingFetcher: ImageFetching {
            func fetch(_ url: URL) async throws -> Data { throw URLError(.timedOut) }
        }
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pipeline = CutoutPipeline(
            directory: dir, baseURL: baseURL, fetcher: FailingFetcher(), processor: FakeProcessor(), minimumInterval: 0
        )
        let outcome = try await pipeline.run(products: [product("1", image: "one")])
        #expect(outcome.products[0].image.cutoutURL == nil)
        #expect(outcome.summary.failed == 1)
    }
}
