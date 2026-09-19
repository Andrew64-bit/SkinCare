import Foundation
import Synchronization
@testable import SkinCareKit

final class FakeRemote: CatalogRemote {
    private let result: Mutex<Result<RemoteFetchResult, any Error>>
    private let etags = Mutex<[String?]>([])

    init(_ result: Result<RemoteFetchResult, any Error>) {
        self.result = Mutex(result)
    }

    var callCount: Int { etags.withLock { $0.count } }
    var receivedETags: [String?] { etags.withLock { $0 } }

    func fetch(ifNoneMatch etag: String?) async throws -> RemoteFetchResult {
        etags.withLock { $0.append(etag) }
        return try result.withLock { try $0.get() }
    }
}
