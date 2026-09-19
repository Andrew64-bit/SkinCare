import Foundation

public protocol OBFSearching: Sendable {
    func search(categoryTag: String, page: Int) async throws -> OBFSearchResponse
}

public enum OBFClientError: Error, Equatable, Sendable {
    case httpStatus(Int)
    case notHTTP
}

/// Client minimo per `GET /api/v2/search` di Open Beauty Facts: User-Agent identificativo obbligatorio,
/// passaggio dal rate limiter prima di ogni richiesta, `page_size` ≤ 100 come da documentazione.
public struct OBFClient: OBFSearching {
    public static let defaultBaseURL = URL(string: "https://world.openbeautyfacts.org")!
    public static let searchFields = [
        "code", "product_name", "product_name_it", "product_name_en", "product_name_fr", "brands",
        "generic_name", "generic_name_it", "generic_name_en", "generic_name_fr", "quantity", "categories_tags",
        "image_front_url", "image_front_small_url", "ingredients_text", "ingredients_text_it",
        "ingredients_text_en", "ingredients_text_fr", "lang", "countries_tags", "labels_tags",
        "last_modified_t", "unique_scans_n", "ingredients_n", "unknown_ingredients_n", "images"
    ]

    public let baseURL: URL
    private let userAgent: String
    private let rateLimiter: RateLimiter
    private let session: URLSession
    private let pageSize: Int

    public init(
        userAgent: String,
        rateLimiter: RateLimiter,
        session: URLSession = .shared,
        baseURL: URL = OBFClient.defaultBaseURL,
        pageSize: Int = 100
    ) {
        self.userAgent = userAgent
        self.rateLimiter = rateLimiter
        self.session = session
        self.baseURL = baseURL
        self.pageSize = min(pageSize, 100)
    }

    public func searchURL(categoryTag: String, page: Int) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: "api/v2/search"), resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "categories_tags", value: "en:\(categoryTag)"),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "lc", value: "it"),
            URLQueryItem(name: "fields", value: Self.searchFields.joined(separator: ","))
        ]
        return components.url!
    }

    public func search(categoryTag: String, page: Int) async throws -> OBFSearchResponse {
        try await rateLimiter.waitTurn()
        var request = URLRequest(url: searchURL(categoryTag: categoryTag, page: page), timeoutInterval: 60)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OBFClientError.notHTTP }
        guard http.statusCode == 200 else { throw OBFClientError.httpStatus(http.statusCode) }
        return try OBFDecoder.searchResponse(from: data)
    }
}
