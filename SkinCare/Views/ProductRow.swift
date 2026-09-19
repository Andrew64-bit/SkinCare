import SkinCareKit
import SwiftUI

struct ProductRow: View {
    let product: Product

    /// Testo attenuato ma con contrasto ≥ 4.5:1 in entrambi gli aspetti: `secondaryLabel` di sistema
    /// si ferma a circa 3.5:1 su sfondo bianco e non supera l'audit di accessibilità.
    static let mutedText = Color(.label).opacity(0.7)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProductImageView(product: product)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.headline)
                    .accessibilityIdentifier("product.name.\(product.id)")
                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(Self.mutedText)
                // Nessun troncamento: l'audit di accessibilità segnala il testo tagliato e la descrizione è breve.
                Text(product.description)
                    .font(.footnote)
                    .foregroundStyle(Self.mutedText)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("product.row.\(product.id)")
        .productContextMenu(for: product)
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
