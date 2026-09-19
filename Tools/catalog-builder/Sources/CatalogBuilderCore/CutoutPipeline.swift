import Foundation
import SkinCareKit

public protocol ImageFetching: Sendable {
    func fetch(_ url: URL) async throws -> Data
}

/// Scarica dal CDN immagini di Open Beauty Facts con User-Agent identificativo.
public struct URLSessionImageFetcher: ImageFetching {
    private let session: URLSession
    private let userAgent: String

    public init(session: URLSession = .shared, userAgent: String) {
        self.session = session
        self.userAgent = userAgent
    }

    public func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}

/// Stato per l'elaborazione incrementale: un'immagine si rielabora solo se l'URL sorgente cambia.
public struct CutoutManifest: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var sourceURL: URL
        public var verdict: CutoutVerdict
        public var processedAt: Date
    }

    public static let fileName = "manifest.json"
    public var entries: [String: Entry] = [:]

    public init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    public static func load(from directory: URL) throws -> CutoutManifest {
        let url = directory.appending(path: fileName)
        guard let data = try? Data(contentsOf: url) else { return CutoutManifest() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CutoutManifest.self, from: data)
    }

    public func save(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: directory.appending(path: Self.fileName), options: .atomic)
    }
}

public struct CutoutSummary: Sendable, Equatable {
    public var processed = 0
    public var reused = 0
    public var clean = 0
    public var hand = 0
    public var badCoverage = 0
    public var failed = 0

    public var description: String {
        "ritagli: elaborati \(processed), riusati \(reused), puliti \(clean), con mano \(hand), "
            + "copertura inutilizzabile \(badCoverage), falliti \(failed)"
    }
}

public struct CutoutOutcome: Sendable {
    public var products: [Product]
    public var summary: CutoutSummary
}

/// Per ogni prodotto: scarica la foto (≤ 1 richiesta/s), la ritaglia, scrive `<barcode>.png` se il
/// cancello passa e collega `cutoutURL`. Un errore su una foto non ferma la corsa.
public struct CutoutPipeline: Sendable {
    private let directory: URL
    private let baseURL: URL
    private let fetcher: any ImageFetching
    private let processor: any CutoutProcessing
    private let limiter: RateLimiter

    public init(
        directory: URL, baseURL: URL, fetcher: any ImageFetching, processor: any CutoutProcessing = ImageCutout(),
        minimumInterval: TimeInterval = 1.0
    ) {
        self.directory = directory
        self.baseURL = baseURL
        self.fetcher = fetcher
        self.processor = processor
        self.limiter = RateLimiter(minimumInterval: minimumInterval)
    }

    public func run(products: [Product]) async throws -> CutoutOutcome {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var manifest = try CutoutManifest.load(from: directory)
        var summary = CutoutSummary()
        var output = products
        for index in output.indices {
            let product = output[index]
            let file = directory.appending(path: "\(product.id).png")
            if let entry = manifest.entries[product.id], entry.sourceURL == product.image.url400,
               entry.verdict != .clean || FileManager.default.fileExists(atPath: file.path()) {
                summary.reused += 1
                output[index].image.cutoutURL = entry.verdict == .clean ? link(for: product.id) : nil
                continue
            }
            output[index].image.cutoutURL = nil
            guard let result = await process(product, summary: &summary) else { continue }
            if result.verdict == .clean, let png = result.png {
                try png.write(to: file, options: .atomic)
                output[index].image.cutoutURL = link(for: product.id)
            }
            manifest.entries[product.id] = CutoutManifest.Entry(
                sourceURL: product.image.url400, verdict: result.verdict, processedAt: Date()
            )
            if summary.processed % 20 == 0 { try manifest.save(to: directory) }
        }
        try manifest.save(to: directory)
        return CutoutOutcome(products: output, summary: summary)
    }

    private func link(for id: String) -> URL {
        baseURL.appending(path: "\(id).png")
    }

    private func process(_ product: Product, summary: inout CutoutSummary) async -> CutoutResult? {
        do {
            try await limiter.waitTurn()
            let data = try await fetcher.fetch(product.image.url400)
            let result = try processor.process(imageData: data)
            summary.processed += 1
            switch result.verdict {
            case .clean: summary.clean += 1
            case .hand: summary.hand += 1
            case .badCoverage: summary.badCoverage += 1
            }
            return result
        } catch {
            summary.failed += 1
            FileHandle.standardError.write(Data("ritaglio \(product.id): \(error)\n".utf8))
            return nil
        }
    }
}
