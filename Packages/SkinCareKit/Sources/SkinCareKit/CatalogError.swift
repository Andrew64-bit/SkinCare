import Foundation

public enum CatalogError: Error, Equatable, Sendable {
    /// Il documento dichiara uno schema che questo Kit non sa leggere.
    case unsupportedSchema(Int)
    /// Dopo la validazione restano meno prodotti del minimo richiesto: il documento non viene accettato.
    case tooFewProducts(valid: Int, minimum: Int)
    /// Il documento non è JSON valido per lo schema atteso.
    case corruptData(String)
}
