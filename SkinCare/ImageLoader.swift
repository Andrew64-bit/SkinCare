import Foundation
import Observation
import UIKit

/// Caricatore di immagini con cache in memoria, cache HTTP su disco (URLCache della sessione) e un
/// tentativo di ripetizione sugli errori di rete. Le richieste per lo stesso URL vengono condivise.
@Observable
final class ImageLoader {
    private let session: URLSession
    private let memoryCache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init(session: URLSession) {
        self.session = session
        memoryCache.countLimit = 400
    }

    func cachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        if let running = inFlight[url] { return await running.value }
        let session = self.session
        let task = Task.detached(priority: .userInitiated) { await Self.fetch(url, session: session) }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image {
            memoryCache.setObject(image, forKey: url as NSURL)
        }
        return image
    }

    nonisolated private static func fetch(_ url: URL, session: URLSession) async -> UIImage? {
        for attempt in 0..<2 {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
                return UIImage(data: data)
            } catch is CancellationError {
                return nil
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(for: .milliseconds(400))
                }
            }
        }
        return nil
    }
}
