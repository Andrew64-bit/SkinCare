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

    static func ingredientTokens(from text: String, max: Int) -> [String] {
        let cleaned = text
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { token in
                token.replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty && $0.count <= 60 }
        return Array(cleaned.prefix(max))
    }
}
