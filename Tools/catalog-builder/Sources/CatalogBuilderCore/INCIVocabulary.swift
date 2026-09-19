import Foundation

/// Prime parole di ingredienti cosmetici comuni (INCI e nomi in it/fr/en/de/es). Serve al controllo di
/// plausibilità: una lista di ingredienti vera ne contiene quasi sempre una fra i primi quattro token;
/// un indirizzo, un codice o la lista di un alimento no.
public enum INCIVocabulary {
    static let firstWords: Set<String> = [
        // acqua e basi
        "aqua", "water", "eau", "acqua", "agua", "wasser", "glycerin", "glycerine", "glycerol", "glicerina",
        "glyzerin", "alcohol", "alcool", "alkohol", "ethanol", "propanediol", "butylene", "propylene", "pentylene",
        "hexylene", "dipropylene", "caprylyl", "1,2-hexanediol", "paraffinum", "petrolatum", "vaselina", "mineral",
        "squalane", "squalene", "isohexadecane", "isododecane", "dimethicone", "cyclopentasiloxane",
        "cyclomethicone", "cyclohexasiloxane", "silica", "talc", "kaolin", "bentonite", "mica",
        // alcoli grassi, esteri, emulsionanti
        "cetearyl", "cetyl", "stearyl", "behenyl", "myristyl", "octyldodecanol", "glyceryl", "polyglyceryl",
        "sorbitan", "polysorbate", "peg", "peg-100", "peg-40", "ppg", "steareth", "ceteareth", "laureth",
        "isopropyl", "ethylhexyl", "caprylic", "caprylic/capric", "coco-caprylate", "coco-caprylate/caprate",
        "dicaprylyl", "c12-15", "c12-20", "cetearyl", "stearic", "palmitic", "lauric", "myristic", "oleic",
        "hydrogenated", "triglyceride", "palmitate", "myristate", "stearate", "oleate", "isostearate",
        "isononyl", "diisopropyl", "dicaprylyl", "triethylhexanoin", "lanolin", "cera", "beeswax", "cire",
        "carnauba", "candelilla", "shea", "butyrospermum", "burro", "beurre", "butter", "karité", "karite",
        // tensioattivi
        "sodium", "potassium", "ammonium", "disodium", "tetrasodium", "coco-glucoside", "decyl", "lauryl",
        "cocamidopropyl", "coco-betaine", "cocamide", "lauroyl", "sarcosinate", "glutamate", "sulfate",
        // attivi e umettanti
        "niacinamide", "panthenol", "allantoin", "urea", "urée", "hyaluronic", "hyaluronate", "tocopherol",
        "tocopheryl", "retinol", "retinyl", "ascorbic", "ascorbyl", "salicylic", "lactic", "glycolic", "citric",
        "acido", "acide", "acid", "adenosine", "caffeine", "bisabolol", "ceramide", "cholesterol", "betaine",
        "sorbitol", "trehalose", "glucose", "sucrose", "fructose", "maltodextrin", "arginine", "glycine",
        "serine", "alanine", "lysine", "proline", "peptide", "palmitoyl", "acetyl", "zinc", "magnesium",
        "calcium", "copper", "titanium", "iron", "ci", "bakuchiol", "ectoin", "madecassoside", "resveratrol",
        "ferulic", "azelaic", "kojic", "arbutin", "tranexamic", "menthol", "camphor", "menthyl",
        // filtri solari
        "homosalate", "octocrylene", "octisalate", "avobenzone", "oxybenzone", "butyl", "bis-ethylhexyloxyphenol",
        "ethylhexyl", "diethylamino", "drometrizole", "methylene", "phenylbenzimidazole", "terephthalylidene",
        "tris-biphenyl", "polysilicone-15", "titanium", "zinc",
        // conservanti, profumo, allergeni
        "phenoxyethanol", "ethylhexylglycerin", "benzyl", "benzoate", "dehydroacetic", "chlorphenesin",
        "methylparaben", "propylparaben", "parabens", "parfum", "profumo", "fragrance", "perfume", "aroma",
        "limonene", "linalool", "citronellol", "geraniol", "coumarin", "citral", "eugenol", "hexyl", "bht",
        "bha", "edta", "carbomer", "xanthan", "acrylates", "acrylates/c10-30", "sclerotium", "cellulose",
        "hydroxyethylcellulose", "hydroxypropyl", "polyacrylate", "carrageenan", "gellan", "agar", "alginate",
        // oli, estratti, botanici
        "oil", "huile", "olio", "öl", "aceite", "extract", "extrait", "estratto", "extrakt", "extracto", "juice",
        "jus", "succo", "leaf", "flower", "seed", "root", "fruit", "kernel", "aloe", "camellia", "chamomilla",
        "calendula", "helianthus", "prunus", "simmondsia", "cocos", "olea", "ricinus", "argania", "persea",
        "macadamia", "oryza", "rosa", "vitis", "borago", "oenothera", "linum", "cannabis", "theobroma",
        "mangifera", "avena", "hamamelis", "centella", "ginkgo", "panax", "glycyrrhiza", "melaleuca", "lavandula",
        "eucalyptus", "mentha", "citrus", "rosmarinus", "salvia", "thymus", "zingiber", "curcuma", "cucumis",
        "solanum", "daucus", "hordeum", "triticum", "zea", "glycine", "sesamum", "corylus", "juglans",
        "hippophae", "punica", "vaccinium", "malus", "pyrus", "ananas", "carica", "actinidia", "musa", "cocos"
    ]

    /// Vero se la prima parola del token (normalizzata: minuscolo, senza accenti, senza parentesi) è nota.
    public static func isKnown(_ token: String) -> Bool {
        var text = token.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        text = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard let first = text.split(whereSeparator: { $0 == " " || $0 == "*" }).first else { return false }
        let word = String(first).trimmingCharacters(in: .punctuationCharacters.subtracting(CharacterSet(charactersIn: "-/,")))
        if firstWords.contains(word) { return true }
        if let slash = word.split(separator: "/").first, firstWords.contains(String(slash)) { return true }
        if let dash = word.split(separator: "-").first, firstWords.contains(String(dash)) { return true }
        return false
    }
}
