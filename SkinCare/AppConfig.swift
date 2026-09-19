import Foundation

nonisolated enum AppConfig {
    /// URL pubblico del catalogo (GitHub Pages). Finché non è pubblicato risponde 404 e il refresh
    /// fallisce in silenzio: l'app continua a usare lo snapshot incluso o l'ultimo catalogo valido.
    static let remoteCatalogURL = URL(string: "https://andrew64-bit.github.io/SkinCare/catalog/catalog.json")!
    /// URL servito dallo stub di rete durante i test UI (mai raggiunto davvero).
    static let uiTestRemoteCatalogURL = URL(string: "https://catalog.skincare.test/catalog.json")!
    static let catalogRepositoryURL = URL(string: "https://github.com/Andrew64-bit/SkinCare")!
    static let supportEmail = "vannozziandrea@gmail.com"
    static let refreshInterval: TimeInterval = 86_400
}
