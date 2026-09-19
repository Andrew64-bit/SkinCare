import Foundation
import Testing
@testable import SkinCareKit

@Suite("Catalog repository")
@MainActor
struct CatalogRepositoryTests {
    private let now = TestCatalogs.generatedAt.addingTimeInterval(7 * 86_400) // una settimana dopo il bundle
    private let bundled = TestCatalogs.make(productCount: 3)

    private func makeStore() -> (CatalogStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "SkinCareKitRepo-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (CatalogStore(directory: dir, minimumProducts: 1), dir)
    }

    private func newer(by days: Double, count: Int = 4) -> Catalog {
        TestCatalogs.make(productCount: count, generatedAt: bundled.generatedAt.addingTimeInterval(days * 86_400))
    }

    private func makeRepository(store: CatalogStore, remote: (any CatalogRemote)?) -> CatalogRepository {
        let fixedNow = now
        return CatalogRepository(bundled: bundled, store: store, remote: remote, now: { fixedNow })
    }

    @Test("with an empty store the bundled snapshot is published")
    func loadsBundledWhenStoreEmpty() async {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = makeRepository(store: store, remote: nil)
        await repo.load()
        #expect(repo.catalog == bundled)
        #expect(repo.lastCheckedAt == nil)
    }

    @Test("a stored catalog newer than the bundle wins")
    func loadsStoredWhenNewer() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stored = newer(by: 2)
        try await store.save(StoredCatalog(catalog: stored, etag: "\"s\"", lastCheckedAt: now.addingTimeInterval(-60)))
        let repo = makeRepository(store: store, remote: nil)
        await repo.load()
        #expect(repo.catalog == stored)
        #expect(repo.lastCheckedAt == now.addingTimeInterval(-60))
    }

    @Test("a stored catalog older than the bundle (app updated) is superseded by the bundle")
    func bundleWinsWhenNewerThanStore() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await store.save(StoredCatalog(catalog: newer(by: -30), etag: nil, lastCheckedAt: now))
        let repo = makeRepository(store: store, remote: nil)
        await repo.load()
        #expect(repo.catalog == bundled)
    }

    @Test("refreshIfNeeded skips when the last check is within the interval and never calls the remote")
    func skipsRecentCheck() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await store.save(StoredCatalog(catalog: newer(by: 1), etag: nil, lastCheckedAt: now.addingTimeInterval(-3600)))
        let remote = FakeRemote(.success(.notModified))
        let repo = makeRepository(store: store, remote: remote)
        await repo.load()
        let outcome = await repo.refreshIfNeeded()
        #expect(outcome == .skipped(.checkedRecently))
        #expect(remote.callCount == 0)
    }

    @Test("refreshIfNeeded without a remote is skipped")
    func skipsWithoutRemote() async {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = makeRepository(store: store, remote: nil)
        await repo.load()
        #expect(await repo.refreshIfNeeded() == .skipped(.noRemote))
    }

    @Test("an updated, newer remote catalog replaces the current one and is persisted")
    func updatedReplacesAndPersists() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fresh = newer(by: 5)
        let remote = FakeRemote(.success(.updated(fresh, etag: "\"v9\"")))
        let repo = makeRepository(store: store, remote: remote)
        await repo.load()
        let outcome = await repo.refreshIfNeeded()
        #expect(outcome == .updated)
        #expect(repo.catalog == fresh)
        #expect(repo.lastCheckedAt == now)
        let persisted = try #require(await store.load())
        #expect(persisted.catalog == fresh)
        #expect(persisted.etag == "\"v9\"")
        #expect(persisted.lastCheckedAt == now)
    }

    @Test("304 keeps the catalog and records the check time persistently")
    func notModifiedRecordsCheck() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let remote = FakeRemote(.success(.notModified))
        let repo = makeRepository(store: store, remote: remote)
        await repo.load()
        let outcome = await repo.refresh()
        #expect(outcome == .notModified)
        #expect(repo.catalog == bundled)
        #expect(repo.lastCheckedAt == now)
        let persisted = try #require(await store.load())
        #expect(persisted.lastCheckedAt == now)
        #expect(persisted.catalog == bundled)
    }

    @Test("a failing remote leaves catalog and check time untouched")
    func failureKeepsState() async {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let remote = FakeRemote(.failure(URLError(.notConnectedToInternet)))
        let repo = makeRepository(store: store, remote: remote)
        await repo.load()
        let outcome = await repo.refresh()
        guard case .failed = outcome else {
            Issue.record("expected .failed, got \(outcome)")
            return
        }
        #expect(repo.catalog == bundled)
        #expect(repo.lastCheckedAt == nil)
        #expect(repo.isRefreshing == false)
    }

    @Test("a remote catalog older than the current one is ignored")
    func olderRemoteIgnored() async {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let remote = FakeRemote(.success(.updated(newer(by: -3), etag: "\"old\"")))
        let repo = makeRepository(store: store, remote: remote)
        await repo.load()
        let outcome = await repo.refresh()
        #expect(outcome == .skipped(.olderThanCurrent))
        #expect(repo.catalog == bundled)
    }

    @Test("the stored ETag is sent on the next refresh")
    func sendsStoredETag() async throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await store.save(StoredCatalog(catalog: newer(by: 1), etag: "\"e7\"", lastCheckedAt: now.addingTimeInterval(-2 * 86_400)))
        let remote = FakeRemote(.success(.notModified))
        let repo = makeRepository(store: store, remote: remote)
        await repo.load()
        _ = await repo.refreshIfNeeded()
        #expect(remote.receivedETags == ["\"e7\""])
    }
}
