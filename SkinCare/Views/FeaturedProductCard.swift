import SkinCareKit
import SwiftUI

/// Scheda «in evidenza» a tutta larghezza sotto il titolo grande (come il landmark in evidenza del sample
/// Landmarks): la foto a 400 px del primo prodotto del catalogo riempie la scheda, un gradiente scurisce
/// il basso, marca come occhiello e nome del prodotto in bianco su uno scrim garantito, così il contrasto
/// regge su qualunque foto. La scheda cresce con la taglia di testo (`minHeight`, nessun `lineLimit`).
struct FeaturedProductCard: View {
    let product: Product
    @Environment(ImageLoader.self) private var loader
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.brand)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
            Text(product.name)
                .font(.title2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 4)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .bottomLeading)
        .background { photo }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("In evidenza: \(product.name), \(product.brand)")
        .accessibilityIdentifier("product.featured.\(product.id)")
        .productContextMenu(for: product)
        .task(id: product.image.url400) { await load() }
    }

    /// Foto ritagliata a riempire esattamente la scheda (lo sfondo prende la misura del testo) con il
    /// gradiente in basso; in attesa o senza rete resta un fondo neutro con l'icona segnaposto.
    private var photo: some View {
        Color(.secondarySystemFill)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if failed {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: UnitPoint(x: 0.5, y: 0.3),
                    endPoint: .bottom
                )
            }
            .clipped()
    }

    private func load() async {
        if let cached = loader.cachedImage(for: product.image.url400) {
            image = cached
            return
        }
        failed = false
        if let loaded = await loader.image(for: product.image.url400) {
            image = loaded
        } else {
            image = nil
            failed = true
        }
    }
}
