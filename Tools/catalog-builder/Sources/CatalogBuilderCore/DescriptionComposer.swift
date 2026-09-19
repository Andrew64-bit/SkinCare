import Foundation

public struct ComposedDescription: Equatable, Sendable {
    public var description: String
    public var ingredientsPreview: String?
}

/// Compone una descrizione in italiano dai soli campi strutturati del prodotto: nessun claim di
/// efficacia, nessuna interpretazione. Il nome generico dichiarato dal prodotto sostituisce la frase
/// «{categoria} di {marca}» solo se è sobrio (niente punti esclamativi, ≤ 80 caratteri).
public enum DescriptionComposer {
    public static func compose(
        genericName: String?,
        categorySingular: String,
        brand: String,
        quantity: String?,
        ingredientsText: String?,
        maxIngredients: Int = 4
    ) -> ComposedDescription {
        var sentence = sanitizedGenericName(genericName)
            ?? "\(categorySingular) di \(brand.trimmingCharacters(in: .whitespacesAndNewlines))"
        if let quantity = quantity?.trimmingCharacters(in: .whitespacesAndNewlines), !quantity.isEmpty {
            sentence += ", \(quantity)"
        }
        sentence += "."

        let tokens = ingredientTokens(from: ingredientsText ?? "", max: maxIngredients)
        let preview = tokens.isEmpty ? nil : tokens.joined(separator: ", ")
        if let preview {
            sentence += " Ingredienti principali: \(preview)" + (preview.hasSuffix(".") ? "" : ".")
        }
        return ComposedDescription(description: sentence, ingredientsPreview: preview)
    }

    static func sanitizedGenericName(_ raw: String?) -> String? {
        guard var name = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        guard !name.contains("!") else { return nil }
        while let last = name.last, ".;,: ".contains(last) {
            name.removeLast()
        }
        guard (3...80).contains(name.count) else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Etichetta iniziale tipo «603258 115 - INGREDIENTS:» / «Ingredienti:» / «INCI:».
    private static let leadingLabelPattern = #"^[^,;•·\n]{0,40}?(ingredients?|ingredienti|inci|composition|composizione)\s*:"#
    private static let separators = CharacterSet(charactersIn: ",;•·|\n\r")

    /// Spezza la lista INCI nei singoli ingredienti: separatori reali (virgola, punto e virgola, punto
    /// elenco, a capo, «. » seguito da maiuscola), sinonimi «Aqua/Water» ridotti al primo nome quando ogni
    /// parte è un ingrediente noto, asterischi tolti, liste tutte in maiuscolo normalizzate. Restano solo i
    /// primi `max` token accettabili (con almeno una lettera, ≤ 60 caratteri, senza `[ ] ? °`).
    static func ingredientTokens(from text: String, max: Int) -> [String] {
        Array(cleanedTokens(from: text).filter(isAcceptable).prefix(max))
    }

    /// Token puliti ma NON filtrati per accettabilità: servono a verificare che i primi ingredienti
    /// dell'anteprima siano davvero i primi della lista (nessun token scartato in silenzio).
    static func rawIngredientTokens(from text: String, max: Int) -> [String] {
        Array(cleanedTokens(from: text).prefix(max))
    }

    static func isAcceptable(_ token: String) -> Bool {
        !token.isEmpty && token.count <= 60
            && token.range(of: "[A-Za-z]", options: .regularExpression) != nil
            && token.range(of: #"[\[\]?°]"#, options: .regularExpression) == nil
    }

    private static func cleanedTokens(from text: String) -> [String] {
        var body = text
        if let label = body.range(of: leadingLabelPattern, options: [.regularExpression, .caseInsensitive]) {
            body.removeSubrange(label)
        }
        // Codice iniziale senza etichetta («2050519 10 - Aqua…»).
        if let code = body.range(of: #"^\s*\d[\d\s\-–]*"#, options: .regularExpression) {
            body.removeSubrange(code)
        }
        // «Aqua. Glycerin»: un punto seguito da spazio e maiuscola separa due ingredienti.
        body = body.replacingOccurrences(of: #"\.\s+(?=\p{Lu})"#, with: ", ", options: .regularExpression)
        let shouting = body.range(of: "[a-z]", options: .regularExpression) == nil
        return body
            .components(separatedBy: separators)
            .map { raw -> String in
                var token = raw.replacingOccurrences(of: "*", with: "")
                // Etichette residue («/Ingrediente:/Съставки (INCI): Aqua»): resta solo ciò che segue l'ultimo «:».
                if let label = token.range(of: ":", options: .backwards) {
                    token = String(token[label.upperBound...])
                }
                while token.contains("..") {
                    token = token.replacingOccurrences(of: "..", with: ".")
                }
                token = token
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                while token.hasPrefix("/") || token.hasPrefix("-") {
                    token.removeFirst()
                }
                token = reducingSynonyms(token)
                return shouting ? token.capitalized : token
            }
            .filter { !$0.isEmpty }
    }

    /// «Aqua/Water», «aqua/water/eau», «Aqua / Water», «Butyrospermum Parkii Butter/Shea Butter»: se ogni
    /// parte inizia con un ingrediente noto sono sinonimi e resta la prima. «Caprylic/Capric Triglyceride»
    /// o «Dimethicone/Vinyl Dimethicone Crosspolymer» restano interi (una parte non è un nome noto).
    private static func reducingSynonyms(_ token: String) -> String {
        guard token.contains("/") else { return token }
        let parts = token.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty && INCIVocabulary.isKnown($0) }) else { return token }
        return parts[0]
    }
}
