import CatalogBuilderCore
import Foundation
import SkinCareKit

/// Uso:
///   catalog-builder build --out <file.json> [--per-category 100] [--max-pages 5] [--min-interval 6.5]
///                         [--user-agent "App/Versione (contatto)"]
///   catalog-builder verify <file.json>
/// Exit: 0 ok · 1 soglia di qualità non superata · 2 errore d'uso o di rete.
enum CLI {
    static let defaultUserAgent = "SkinCareCatalogBuilder/0.1 (vannozziandrea@gmail.com)"

    static func run(_ arguments: [String]) async -> Int32 {
        guard let command = arguments.first else { return usage() }
        switch command {
        case "build": return await build(Array(arguments.dropFirst()))
        case "verify": return verify(Array(arguments.dropFirst()))
        default: return usage()
        }
    }

    static func usage() -> Int32 {
        FileHandle.standardError.write(Data("""
        uso: catalog-builder build --out <file.json> [--per-category N] [--max-pages N] [--min-interval S] [--user-agent UA]
             catalog-builder verify <file.json>
        predefiniti: --per-category 100 --max-pages 5 --min-interval 6.5

        """.utf8))
        return 2
    }

    static func option(_ name: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static func build(_ args: [String]) async -> Int32 {
        guard let out = option("--out", in: args) else { return usage() }
        // Predefiniti v0.2: fino a 100 prodotti per categoria su al massimo 5 pagine (ricerca «il prodotto che uso»).
        let perCategory = option("--per-category", in: args).flatMap(Int.init) ?? 100
        let maxPages = option("--max-pages", in: args).flatMap(Int.init) ?? 5
        let minInterval = option("--min-interval", in: args).flatMap(Double.init) ?? 6.5
        let userAgent = option("--user-agent", in: args) ?? defaultUserAgent

        let client = OBFClient(userAgent: userAgent, rateLimiter: RateLimiter(minimumInterval: minInterval))
        let assembler = CatalogAssembler(
            search: client, options: AssemblerOptions(perCategory: perCategory, maxPagesPerCategory: maxPages)
        )
        do {
            let started = Date()
            let result = try await assembler.build()
            for report in result.reports {
                print("\(report.tag): pagine \(report.pagesFetched)+\(report.targetedPages) mirate, "
                    + "visti \(report.productsSeen), selezionati \(report.productsSelected) "
                    + "(Italia \(report.italianProducts))")
            }
            print("crediti foto recuperati dall'endpoint prodotto: \(result.creditsRecovered)")
            let data = try CatalogCodec.encode(result.catalog)
            let url = URL(fileURLWithPath: out)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            print("scritto \(out): \(result.catalog.products.count) prodotti, \(data.count) byte, "
                + "\(Int(Date().timeIntervalSince(started))) s")
            return report(result.catalog)
        } catch {
            FileHandle.standardError.write(Data("errore: \(error)\n".utf8))
            return 2
        }
    }

    static func verify(_ args: [String]) -> Int32 {
        guard let path = args.first else { return usage() }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let catalog = try CatalogCodec.decode(data, minimumProducts: 1)
            return report(catalog)
        } catch {
            FileHandle.standardError.write(Data("errore: \(error)\n".utf8))
            return 2
        }
    }

    static func report(_ catalog: Catalog) -> Int32 {
        let quality = CatalogQuality.check(catalog)
        print("qualità: \(quality.productCount) prodotti, \(quality.categoryCount) categorie, "
            + "generato \(catalog.generatedAt.formatted(.iso8601))")
        for issue in quality.issues {
            print("  ✘ \(issue)")
        }
        print(quality.passes ? "QUALITY=PASS" : "QUALITY=FAIL")
        return quality.passes ? 0 : 1
    }
}

exit(await CLI.run(Array(CommandLine.arguments.dropFirst())))
