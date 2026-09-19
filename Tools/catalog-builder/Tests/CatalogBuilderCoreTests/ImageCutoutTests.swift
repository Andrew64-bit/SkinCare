import AppKit
import CoreImage
import Foundation
import Testing
@testable import CatalogBuilderCore

@Suite("Image cutout")
struct ImageCutoutTests {
    // MARK: - Cancello (logica pura)

    @Test("coverage 12–92 % with no person is clean")
    func cleanVerdict() {
        #expect(CutoutGate.verdict(coverage: 0.5, personShare: 0.0, instances: 1) == .clean)
        #expect(CutoutGate.verdict(coverage: 0.12, personShare: 0.08, instances: 3) == .clean)
    }

    @Test("a person share above 8 % is a hand-held photo")
    func handVerdict() {
        #expect(CutoutGate.verdict(coverage: 0.5, personShare: 0.09, instances: 1) == .hand)
    }

    @Test("coverage below 12 % or above 92 % is unusable")
    func coverageVerdict() {
        #expect(CutoutGate.verdict(coverage: 0.11, personShare: 0, instances: 1) == .badCoverage)
        #expect(CutoutGate.verdict(coverage: 0.93, personShare: 0, instances: 1) == .badCoverage)
    }

    @Test("no subject at all is unusable")
    func noSubject() {
        #expect(CutoutGate.verdict(coverage: 0, personShare: 0, instances: 0) == .badCoverage)
    }

    // MARK: - Composizione con maschera sintetica (senza Vision)

    /// Immagine 300×200 con un rettangolo rosso 100×60 in (50,70) e maschera che lo copre esattamente.
    private func syntheticImageAndMask() -> (CIImage, CIImage) {
        let frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        let rect = CGRect(x: 50, y: 70, width: 100, height: 60)
        let image = CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.9)).cropped(to: frame)
        let subject = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: rect)
        let mask = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: rect)
            .composited(over: CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: frame))
        return (subject.composited(over: image), mask)
    }

    @Test("the composition is a 400×400 PNG with transparent corners and the subject centered")
    func compositionGeometry() throws {
        let (image, mask) = syntheticImageAndMask()
        let subjectExtent = CGRect(x: 50, y: 70, width: 100, height: 60)
        let png = try #require(ImageCutout.compose(image: image, mask: mask, subjectExtent: subjectExtent))
        let bitmap = try #require(NSBitmapImageRep(data: png))
        #expect(bitmap.pixelsWide == 400)
        #expect(bitmap.pixelsHigh == 400)
        #expect(bitmap.hasAlpha)
        func alpha(_ x: Int, _ y: Int) -> CGFloat { bitmap.colorAt(x: x, y: y)?.alphaComponent ?? -1 }
        #expect(alpha(0, 0) == 0)
        #expect(alpha(399, 399) == 0)
        #expect(alpha(200, 200) == 1)                 // centro: soggetto opaco
        #expect(alpha(200, 40) == 0)                  // sopra il soggetto (margine + bordo): trasparente
        let red = try #require(bitmap.colorAt(x: 200, y: 200)?.usingColorSpace(.sRGB))
        #expect(red.redComponent > 0.9, "\(red)")
        #expect(red.greenComponent < 0.1, "\(red)")
    }

    // MARK: - Integrazione Vision su una foto reale (fixture CC BY-SA, vedi Fixtures/README.md)

    @Test("the Avène fixture photo yields a clean 400×400 cutout with transparent corners")
    func fixturePhotoCutout() throws {
        let url = try #require(Bundle.module.url(
            forResource: "avene-spray-front", withExtension: "jpg", subdirectory: "Fixtures"
        ))
        let result = try ImageCutout.process(imageData: Data(contentsOf: url))
        #expect(result.verdict == .clean, "\(result.verdict) coverage \(result.coverage) person \(result.personShare)")
        #expect(result.coverage > 0.12)
        #expect(result.personShare < 0.08)
        let png = try #require(result.png)
        let bitmap = try #require(NSBitmapImageRep(data: png))
        #expect(bitmap.pixelsWide == 400 && bitmap.pixelsHigh == 400)
        #expect(bitmap.colorAt(x: 2, y: 2)?.alphaComponent == 0)
        #expect(bitmap.colorAt(x: 397, y: 397)?.alphaComponent == 0)
        #expect((bitmap.colorAt(x: 200, y: 200)?.alphaComponent ?? 0) > 0.9)
    }
}
