import Foundation
import Testing
@testable import SkinCareKit

@Suite("Catalog store", .serialized)
struct CatalogStoreTests {
    private func makeStore() -> (CatalogStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "SkinCareKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (CatalogStore(directory: dir, minimumProducts: 1), dir)
    }

    @Test("save then load returns the same stored catalog")
    func saveLoadRoundTrip() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stored = StoredCatalog(catalog: TestCatalogs.make(productCount: 2), etag: "\"abc\"", lastCheckedAt: TestCatalogs.generatedAt)
        try await store.save(stored)
        let loaded = await store.load()
        #expect(loaded == stored)
    }

    @Test("load returns nil when nothing was saved")
    func loadAbsent() async {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let loaded = await store.load()
        #expect(loaded == nil)
    }

    @Test("a corrupt file yields nil and is deleted so the bundle takes over")
    func corruptFileDeleted() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.fileURL)
        let loaded = await store.load()
        #expect(loaded == nil)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path()))
    }

    @Test("a file whose catalog fails validation is treated as corrupt")
    func invalidCatalogTreatedAsCorrupt() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var catalog = TestCatalogs.make(productCount: 1)
        catalog.schemaVersion = 99
        try await store.save(StoredCatalog(catalog: catalog, etag: nil, lastCheckedAt: .now))
        let loaded = await store.load()
        #expect(loaded == nil)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path()))
    }

    @Test("recordCheck updates only lastCheckedAt")
    func recordCheck() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stored = StoredCatalog(catalog: TestCatalogs.make(productCount: 2), etag: "\"e1\"", lastCheckedAt: TestCatalogs.generatedAt)
        try await store.save(stored)
        let later = TestCatalogs.generatedAt.addingTimeInterval(3600)
        try await store.recordCheck(at: later)
        let loaded = try #require(await store.load())
        #expect(loaded.catalog == stored.catalog)
        #expect(loaded.etag == "\"e1\"")
        #expect(loaded.lastCheckedAt == later)
    }

    @Test("the file is excluded from backups")
    func excludedFromBackup() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await store.save(StoredCatalog(catalog: TestCatalogs.make(productCount: 1), etag: nil, lastCheckedAt: .now))
        let values = try store.fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }
}
