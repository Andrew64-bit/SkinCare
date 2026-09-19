import Foundation
import Observation

/// Fonte di verità per la UI: pubblica sempre un catalogo valido (snapshot incluso nell'app o versione
/// salvata più recente) e, al più una volta per intervallo, prova ad aggiornarlo dalla sorgente remota.
/// Un refresh è tutto-o-niente: il catalogo cambia solo se il documento remoto è valido e più recente.
@MainActor
@Observable
public final class CatalogRepository {
    public enum SkipReason: Sendable, Equatable { case noRemote, checkedRecently, olderThanCurrent, alreadyRefreshing }
    public enum RefreshOutcome: Sendable, Equatable { case skipped(SkipReason), notModified, updated, failed(String) }

    public private(set) var catalog: Catalog
    public private(set) var lastCheckedAt: Date?
    public private(set) var isRefreshing = false

    private let bundled: Catalog
    private let store: CatalogStore
    private let remote: (any CatalogRemote)?
    private let refreshInterval: TimeInterval
    private let now: @Sendable () -> Date
    private var etag: String?
    private var loadTask: Task<Void, Never>?

    public init(
        bundled: Catalog,
        store: CatalogStore,
        remote: (any CatalogRemote)?,
        refreshInterval: TimeInterval = 86_400,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.bundled = bundled
        self.catalog = bundled
        self.store = store
        self.remote = remote
        self.refreshInterval = refreshInterval
        self.now = now
    }

    /// Pubblica il più recente fra lo snapshot incluso e il catalogo salvato (un aggiornamento dell'app
    /// può portare uno snapshot più nuovo di quello scaricato in precedenza). Idempotente: la lettura
    /// dello store avviene una sola volta e chi chiama `refreshIfNeeded` prima di `load` la attende.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.readStore() }
        loadTask = task
        await task.value
    }

    private func readStore() async {
        if let stored = await store.load(), stored.catalog.generatedAt >= bundled.generatedAt {
            catalog = stored.catalog
            etag = stored.etag
            lastCheckedAt = stored.lastCheckedAt
        } else {
            catalog = bundled
            etag = nil
            lastCheckedAt = nil
        }
    }

    public func refreshIfNeeded() async -> RefreshOutcome {
        guard remote != nil else { return .skipped(.noRemote) }
        await load()
        if let lastCheckedAt, now().timeIntervalSince(lastCheckedAt) < refreshInterval {
            return .skipped(.checkedRecently)
        }
        return await refresh()
    }

    public func refresh() async -> RefreshOutcome {
        guard let remote else { return .skipped(.noRemote) }
        await load()
        guard !isRefreshing else { return .skipped(.alreadyRefreshing) }
        isRefreshing = true
        defer { isRefreshing = false }

        let result: RemoteFetchResult
        do {
            result = try await remote.fetch(ifNoneMatch: etag)
        } catch {
            return .failed(String(describing: error))
        }

        let checkedAt = now()
        switch result {
        case .notModified:
            await persist(checkedAt: checkedAt)
            return .notModified
        case let .updated(fresh, freshETag):
            guard fresh.generatedAt > catalog.generatedAt else {
                await persist(checkedAt: checkedAt)
                return .skipped(.olderThanCurrent)
            }
            catalog = fresh
            etag = freshETag
            await persist(checkedAt: checkedAt)
            return .updated
        }
    }

    /// Salva catalogo corrente, ETag e data del controllo. Un errore di scrittura non tocca lo stato in
    /// memoria: la UI resta coerente e il prossimo controllo riproverà.
    private func persist(checkedAt: Date) async {
        lastCheckedAt = checkedAt
        try? await store.save(StoredCatalog(catalog: catalog, etag: etag, lastCheckedAt: checkedAt))
    }
}
