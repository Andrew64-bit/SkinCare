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
            sentence += " Ingredienti principali: \(preview)."
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
    /// elenco, a capo), sinonimi «AQUA / WATER» ridotti al primo, asterischi tolti, liste tutte in
    /// maiuscolo normalizzate. Restano solo i primi `max` token con almeno una lettera e ≤ 60 caratteri.
    static func ingredientTokens(from text: String, max: Int) -> [String] {
        var body = text
        if let label = body.range(of: leadingLabelPattern, options: [.regularExpression, .caseInsensitive]) {
            body.removeSubrange(label)
        }
        let shouting = body.range(of: "[a-z]", options: .regularExpression) == nil
        let tokens = body
            .components(separatedBy: separators)
            .map { raw -> String in
                var token = raw.replacingOccurrences(of: "*", with: "")
                if let synonym = token.range(of: " / ") {
                    token = String(token[..<synonym.lowerBound])
                }
                token = token
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return shouting ? token.capitalized : token
            }
            .filter { token in
                !token.isEmpty && token.count <= 60 && token.range(of: "[A-Za-z]", options: .regularExpression) != nil
            }
        return Array(tokens.prefix(max))
    }
}
