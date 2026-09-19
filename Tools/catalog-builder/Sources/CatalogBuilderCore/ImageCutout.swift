import AppKit
import CoreImage
import Foundation
import Vision

public enum CutoutVerdict: String, Codable, Sendable, Equatable {
    /// Soggetto isolato bene: il ritaglio si pubblica.
    case clean
    /// Il soggetto contiene una persona (mano): si tiene la foto originale.
    case hand
    /// Nessun soggetto, o soggetto troppo piccolo/grande (inquadratura piena): si tiene l'originale.
    case badCoverage
}

/// Cancello di qualità del ritaglio: soglie ricavate dalla prova su 30 foto del catalogo (2026-09-19).
public enum CutoutGate {
    public static let minimumCoverage = 0.12
    public static let maximumCoverage = 0.92
    public static let maximumPersonShare = 0.08

    public static func verdict(coverage: Double, personShare: Double, instances: Int) -> CutoutVerdict {
        guard instances > 0, coverage >= minimumCoverage, coverage <= maximumCoverage else { return .badCoverage }
        return personShare > maximumPersonShare ? .hand : .clean
    }
}

public struct CutoutResult: Sendable, Equatable {
    public var verdict: CutoutVerdict
    public var coverage: Double
    public var personShare: Double
    /// PNG 400×400 con trasparenza, presente solo se il verdetto è `clean`.
    public var png: Data?

    public init(verdict: CutoutVerdict, coverage: Double, personShare: Double, png: Data?) {
        self.verdict = verdict
        self.coverage = coverage
        self.personShare = personShare
        self.png = png
    }
}

public protocol CutoutProcessing: Sendable {
    func process(imageData: Data) throws -> CutoutResult
}

public enum CutoutError: Error, Equatable, Sendable {
    case undecodableImage
    case renderFailed
}

/// Ritaglio del prodotto dalla foto con Vision (soggetto in primo piano) e composizione su tela
/// trasparente 400×400. Opera derivata della foto CC BY-SA 3.0: stessa licenza, stesso credito.
public struct ImageCutout: CutoutProcessing {
    public static let canvasSide = 400
    public static let margin = 0.08

    public init() {}

    public func process(imageData: Data) throws -> CutoutResult {
        try Self.process(imageData: imageData)
    }

    public static func process(imageData: Data) throws -> CutoutResult {
        guard let image = CIImage(data: imageData) else { throw CutoutError.undecodableImage }
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let foreground = VNGenerateForegroundInstanceMaskRequest()
        let person = VNGeneratePersonSegmentationRequest()
        person.qualityLevel = .accurate
        person.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try handler.perform([foreground, person])
        guard let result = foreground.results?.first, !result.allInstances.isEmpty else {
            return CutoutResult(verdict: .badCoverage, coverage: 0, personShare: 0, png: nil)
        }
        let stats = MaskStatistics(instanceMask: result.instanceMask, personMask: person.results?.first?.pixelBuffer)
        let verdict = CutoutGate.verdict(
            coverage: stats.coverage, personShare: stats.personShare, instances: result.allInstances.count
        )
        guard verdict == .clean else {
            return CutoutResult(verdict: verdict, coverage: stats.coverage, personShare: stats.personShare, png: nil)
        }
        let buffer = try result.generateMaskedImage(
            ofInstances: IndexSet(integer: stats.largestInstance), from: handler, croppedToInstancesExtent: true
        )
        let cut = CIImage(cvPixelBuffer: buffer)
        guard let png = compose(image: cut, mask: nil, subjectExtent: cut.extent) else { throw CutoutError.renderFailed }
        return CutoutResult(verdict: .clean, coverage: stats.coverage, personShare: stats.personShare, png: png)
    }

    /// Applica la maschera (bianco = soggetto) se data, ritaglia al rettangolo del soggetto, lo scala per
    /// stare nella tela con il margine e lo centra. Restituisce il PNG con trasparenza.
    public static func compose(image: CIImage, mask: CIImage?, subjectExtent: CGRect) -> Data? {
        var subject = image
        if let mask {
            let blend = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: image, kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: mask
            ])
            guard let output = blend?.outputImage else { return nil }
            subject = output
        }
        subject = subject.cropped(to: subjectExtent)
        let side = CGFloat(canvasSide)
        let usable = side * (1 - 2 * CGFloat(margin))
        let scale = min(usable / subjectExtent.width, usable / subjectExtent.height)
        let scaled = subject.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let translation = CGAffineTransform(
            translationX: (side - scaled.extent.width) / 2 - scaled.extent.minX,
            y: (side - scaled.extent.height) / 2 - scaled.extent.minY
        )
        let placed = scaled.transformed(by: translation)
        let canvas = CGRect(x: 0, y: 0, width: side, height: side)
        // Spazio di lavoro predefinito (lineare) e uscita sRGB esplicita: con lo spazio di lavoro sRGB
        // gamma-codificato il rosso puro usciva con verde 0,15.
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let cgImage = CIContext().createCGImage(placed, from: canvas, format: .RGBA8, colorSpace: sRGB)
        else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }
}

/// Vista in sola lettura sulla maschera delle istanze (OneComponent8: valore = indice istanza, 0 = sfondo).
struct InstanceMaskView {
    let base: UnsafeMutablePointer<UInt8>
    let bytesPerRow: Int
    let width: Int
    let height: Int

    func instance(x: Int, y: Int) -> Int { Int(base[y * bytesPerRow + x]) }
}

/// Copertura dell'istanza più grande e quota di «persona» al suo interno.
struct MaskStatistics {
    var largestInstance = 0
    var coverage = 0.0
    var personShare = 0.0

    init(instanceMask: CVPixelBuffer, personMask: CVPixelBuffer?) {
        CVPixelBufferLockBaseAddress(instanceMask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(instanceMask, .readOnly) }
        guard let address = CVPixelBufferGetBaseAddress(instanceMask) else { return }
        let view = InstanceMaskView(
            base: address.assumingMemoryBound(to: UInt8.self),
            bytesPerRow: CVPixelBufferGetBytesPerRow(instanceMask),
            width: CVPixelBufferGetWidth(instanceMask),
            height: CVPixelBufferGetHeight(instanceMask)
        )
        var counts = [Int](repeating: 0, count: 256)
        for y in 0..<view.height {
            for x in 0..<view.width {
                counts[view.instance(x: x, y: y)] += 1
            }
        }
        counts[0] = 0
        guard let largest = counts.indices.max(by: { counts[$0] < counts[$1] }), counts[largest] > 0 else { return }
        largestInstance = largest
        coverage = Double(counts[largest]) / Double(view.width * view.height)
        personShare = Self.personShare(in: view, instance: largest, instancePixels: counts[largest], personMask: personMask)
    }

    private static func personShare(
        in view: InstanceMaskView, instance: Int, instancePixels: Int, personMask: CVPixelBuffer?
    ) -> Double {
        guard let personMask else { return 0 }
        let person = CIImage(cvPixelBuffer: personMask).transformed(by: CGAffineTransform(
            scaleX: CGFloat(view.width) / CGFloat(CVPixelBufferGetWidth(personMask)),
            y: CGFloat(view.height) / CGFloat(CVPixelBufferGetHeight(personMask))
        ))
        var bitmap = [UInt8](repeating: 0, count: view.width * view.height)
        CIContext().render(
            person, toBitmap: &bitmap, rowBytes: view.width,
            bounds: CGRect(x: 0, y: 0, width: view.width, height: view.height), format: .R8, colorSpace: nil
        )
        var both = 0
        for y in 0..<view.height {
            for x in 0..<view.width where view.instance(x: x, y: y) == instance {
                // la bitmap renderizzata da CoreImage ha l'origine in basso: riga speculare
                if bitmap[(view.height - 1 - y) * view.width + x] > 128 { both += 1 }
            }
        }
        return Double(both) / Double(max(instancePixels, 1))
    }
}
