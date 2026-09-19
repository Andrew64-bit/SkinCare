import Foundation
import SkinCareKit
import UIKit

/// Composizione delle dipendenze dell'app. Le modalità di test si attivano solo con variabili
/// d'ambiente (`SKINCARE_UITEST=1`, `SKINCARE_UITEST_NETWORK=deny`) e solo nelle build DEBUG.
@MainActor
final class AppEnvironment {
    enum TestMode {
        case none
        case stubbed
        case offline
    }

    let testMode: TestMode
    let repository: CatalogRepository?
    let loadError: (any Error)?
    let imageLoader: ImageLoader

    init() {
        let environment = ProcessInfo.processInfo.environment
        var mode: TestMode = .none
        #if DEBUG
        if environment["SKINCARE_UITEST"] == "1" {
            mode = environment["SKINCARE_UITEST_NETWORK"] == "deny" ? .offline : .stubbed
            UITestStubURLProtocol.denyAll = (mode == .offline)
            URLProtocol.registerClass(UITestStubURLProtocol.self)
            UIView.setAnimationsEnabled(false)
        }
        #endif
        testMode = mode

        let catalogSession = URLSession(configuration: Self.configuration(cache: nil, testMode: mode))
        let imageCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: Self.cachesDirectory().appending(path: "ProductImages", directoryHint: .isDirectory)
        )
        let imageSession = URLSession(configuration: Self.configuration(cache: imageCache, testMode: mode))
        imageLoader = ImageLoader(session: imageSession)

        let remoteURL = mode == .none ? AppConfig.remoteCatalogURL : AppConfig.uiTestRemoteCatalogURL
        do {
            let bundled = try BundledCatalog.load()
            repository = CatalogRepository(
                bundled: bundled,
                store: CatalogStore(directory: Self.storeDirectory(testMode: mode)),
                remote: RemoteCatalogSource(url: remoteURL, session: catalogSession),
                refreshInterval: AppConfig.refreshInterval
            )
            loadError = nil
        } catch {
            repository = nil
            loadError = error
        }
    }

    private static func configuration(cache: URLCache?, testMode: TestMode) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = cache == nil ? .reloadIgnoringLocalCacheData : .returnCacheDataElseLoad
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        #if DEBUG
        if testMode != .none {
            configuration.protocolClasses = [UITestStubURLProtocol.self] + (configuration.protocolClasses ?? [])
        }
        #endif
        return configuration
    }

    private static func storeDirectory(testMode: TestMode) -> URL {
        if testMode != .none {
            return FileManager.default.temporaryDirectory
                .appending(path: "SkinCareUITest-\(UUID().uuidString)", directoryHint: .isDirectory)
        }
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appending(path: "SkinCare", directoryHint: .isDirectory)
    }

    private static func cachesDirectory() -> URL {
        (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
    }
}
