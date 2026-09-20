import SkinCareKit
import SwiftUI

struct ProductRow: View {
    let product: Product

    /// Testo attenuato ma con contrasto ≥ 4.5:1 in entrambi gli aspetti: `secondaryLabel` di sistema
    /// si ferma a circa 3.5:1 su sfondo bianco e non supera l'audit di accessibilità.
    static let mutedText = Color(.label).opacity(0.7)

    /// Il builder compone `description` come «<generico> di <marca>, <quantità>. Ingredienti principali: <INCI>.».
    static let ingredientsSeparator = ". Ingredienti principali: "

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProductImageView(product: product)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .accessibilityIdentifier("product.name.\(product.id)")
                // Marca a colore pieno: si stacca dalla descrizione attenuata sotto.
                HStack(spacing: 8) {
                    Text(product.brand)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.label))
                    if product.soldInItaly {
                        ItalyBadge(productID: product.id)
                    }
                }
                // Descrizione intera (nessun troncamento né lineLimit: l'audit di accessibilità segnala il testo
                // tagliato) ma in due righe brevi e attenuate, così la riga non si legge come un paragrafo.
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(descriptionLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(Self.mutedText)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("product.row.\(product.id)")
        .productContextMenu(for: product)
    }

    /// Le righe della descrizione: «Crema viso, 400 ml.» (la marca è già sulla riga sopra, quindi
    /// « di <marca>» si toglie dalla prima frase; un nome generico italiano resta com'è) e
    /// «Ingredienti principali: …» (al più 4 ingredienti). Senza separatore: la descrizione intera.
    private var descriptionLines: [String] {
        guard let range = product.description.range(of: Self.ingredientsSeparator) else {
            return [product.description]
        }
        let summary = product.description[..<range.lowerBound]
            .replacingOccurrences(of: " di \(product.brand)", with: "")
        let ingredients = String(product.description[range.upperBound...])
        return [summary + ".", "Ingredienti principali: " + ingredients]
    }
}

extension View {
    /// Menu contestuale condiviso da riga e scheda in evidenza: pagina del prodotto su Open Beauty Facts
    /// (attribuzione per prodotto) e credito della foto (CC BY-SA 3.0).
    func productContextMenu(for product: Product) -> some View {
        contextMenu {
            Link(destination: product.sourceURL) {
                Label("Apri su Open Beauty Facts", systemImage: "safari")
            }
            Button {} label: {
                Label("Foto: \(product.image.credit.uploader) · \(product.image.credit.license)", systemImage: "camera")
            }
            .disabled(true)
        }
    }
}
