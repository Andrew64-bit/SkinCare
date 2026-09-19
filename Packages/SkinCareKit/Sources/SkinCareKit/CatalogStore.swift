import Foundation

/// Catalogo persistito con i metadati del refresh remoto.
public struct StoredCatalog: Codable, Sendable, Equatable {
    public var catalog: Catalog
    public var etag: String?
    public var lastCheckedAt: Date

    public init(catalog: Catalog, etag: String?, lastCheckedAt: Date) {
        self.catalog = catalog
        self.etag = etag
        self.lastCheckedAt = lastCheckedAt
    }
}

/// Un solo file JSON in una directory dell'app (Application Support): scrittura atomica, escluso dal
/// backup, e se il contenuto non è leggibile o non passa la validazione il file viene cancellato così
/// il chiamante riparte dallo snapshot incluso nell'app.
public actor CatalogStore {
    public nonisolated let fileURL: URL
    private let directory: URL
    private let minimumProducts: Int

    public init(directory: URL, minimumProducts: Int = CatalogCodec.defaultMinimumProducts) {
        self.directory = directory
        self.fileURL = directory.appending(path: "catalog-store.json", directoryHint: .notDirectory)
        self.minimumProducts = minimumProducts
    }

    public func load() -> StoredCatalog? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var stored = try decoder.decode(StoredCatalog.self, from: data)
            stored.catalog = try CatalogCodec.validated(stored.catalog, minimumProducts: minimumProducts)
            return stored
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    public func save(_ stored: StoredCatalog) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(stored).write(to: fileURL, options: .atomic)
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    /// Aggiorna solo la data dell'ultimo controllo remoto (risposta 304 o errore transitorio).
    public func recordCheck(at date: Date) throws {
        guard var stored = load() else { return }
        stored.lastCheckedAt = date
        try save(stored)
    }
}
