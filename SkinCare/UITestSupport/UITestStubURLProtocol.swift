#if DEBUG
import Foundation
import SkinCareKit
import UIKit

/// Rete finta per i test UI, dentro il processo dell'app: il catalogo remoto è lo snapshot incluso
/// ridatato al 2027-03-04 (così il test vede il refresh), le immagini sono generate al volo.
/// In modalità `denyAll` ogni richiesta fallisce come se il dispositivo fosse offline.
nonisolated final class UITestStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var denyAll = false
    static let remoteGeneratedAt = ISO8601DateFormatter().date(from: "2027-03-04T00:00:00Z")!

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client, let url = request.url else { return }
        if Self.denyAll {
            client.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        if url.host() == AppConfig.uiTestRemoteCatalogURL.host() {
            guard let body = Self.remoteCatalogData() else {
                client.urlProtocol(self, didFailWithError: URLError(.cannotDecodeContentData))
                return
            }
            respond(url: url, status: 200, headers: ["Content-Type": "application/json", "ETag": "\"uitest\""], body: body)
        } else if url.host()?.hasSuffix("openbeautyfacts.org") == true {
            respond(url: url, status: 200, headers: ["Content-Type": "image/png"], body: Self.imageData(for: url))
        } else {
            client.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, status: Int, headers: [String: String], body: Data) {
        guard let client,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)
        else { return }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: body)
        client.urlProtocolDidFinishLoading(self)
    }

    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    static func remoteCatalogData() -> Data? {
        guard var catalog = try? BundledCatalog.load() else { return nil }
        catalog.generatedAt = remoteGeneratedAt
        return try? CatalogCodec.encode(catalog)
    }

    /// Quadrato colorato (colore derivato dall'URL) con un riquadro chiaro al centro: deterministico,
    /// leggero e senza testo (un testo chiaro su pastello farebbe scattare l'audit di contrasto).
    static func imageData(for url: URL) -> Data {
        // Hash stabile (FNV-1a): `hashValue` ha un seme casuale per processo e cambierebbe la tinta a ogni avvio.
        let hue = CGFloat(stableHash(url.absoluteString) % 360) / 360
        let size = CGSize(width: 200, height: 200)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            UIColor(hue: hue, saturation: 0.35, brightness: 0.92, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(hue: hue, saturation: 0.55, brightness: 0.55, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 50, y: 30, width: 100, height: 140), cornerRadius: 18).fill()
        }
    }
}
#endif
