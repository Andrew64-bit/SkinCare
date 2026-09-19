import Foundation

public enum RemoteFetchResult: Sendable, Equatable {
    case notModified
    case updated(Catalog, etag: String?)
}

public enum RemoteCatalogError: Error, Equatable, Sendable {
    case httpStatus(Int)
    case notHTTP
}

/// Astrazione della sorgente remota, così il repository si testa senza rete.
public protocol CatalogRemote: Sendable {
    func fetch(ifNoneMatch etag: String?) async throws -> RemoteFetchResult
}

/// GET condizionale del `catalog.json` pubblicato (URL statico con ETag). La cache HTTP di URLSession
/// viene ignorata: la validazione con ETag è gestita qui e il risultato persiste nello store.
public struct RemoteCatalogSource: CatalogRemote {
    public let url: URL
    private let session: URLSession
    private let minimumProducts: Int
    private let timeout: TimeInterval

    public init(
        url: URL,
        session: URLSession = .shared,
        minimumProducts: Int = CatalogCodec.defaultMinimumProducts,
        timeout: TimeInterval = 15
    ) {
        self.url = url
        self.session = session
        self.minimumProducts = minimumProducts
        self.timeout = timeout
    }

    public func fetch(ifNoneMatch etag: String?) async throws -> RemoteFetchResult {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RemoteCatalogError.notHTTP }
        switch http.statusCode {
        case 304:
            return .notModified
        case 200:
            let catalog = try CatalogCodec.decode(data, minimumProducts: minimumProducts)
            return .updated(catalog, etag: http.value(forHTTPHeaderField: "ETag"))
        default:
            throw RemoteCatalogError.httpStatus(http.statusCode)
        }
    }
}
