import SkinCareKit
import SwiftUI

/// Scheda «in evidenza» a tutta larghezza sotto il titolo grande (come il landmark in evidenza del sample
/// Landmarks): la foto a 400 px del primo prodotto del catalogo riempie la scheda, un gradiente a tutta
/// larghezza scurisce la metà bassa e marca (occhiello) e nome del prodotto stanno in bianco direttamente
/// sul gradiente, in basso a sinistra, con un'ombra sul testo. Nessun pannello dietro al testo: leggeva
/// come «una card dentro la card». La scheda cresce con la taglia di testo (`minHeight`, nessun `lineLimit`).
struct FeaturedProductCard: View {
    let product: Product
    @Environment(ImageLoader.self) private var loader
    @State private var image: UIImage?
    @State private var failed = false

    /// Gradiente da trasparente (a `scrimStart` dell'altezza) a nero con opacità `scrimOpacity` sul bordo
    /// basso. Partito da metà scheda con 0,6, l'audit di contrasto segnalava l'occhiello («Contrast nearly
    /// passed»: a 0,72 dell'altezza il gradiente valeva 0,26 e su una foto chiara il bianco stava a ~2,9:1);
    /// misurato sui fotogrammi dell'audit, per stare ≥ 4,5:1 anche con la foto più chiara servono ~0,54 di
    /// nero sotto l'occhiello: gradiente su tutta l'altezza (invisibile in alto) fino a 0,75. Mai un pannello
    /// dietro al testo, mai testo meno opaco.
    static let scrimStart: CGFloat = 0.0
    static let scrimOpacity: Double = 0.75

    private var hasCutout: Bool { product.image.cutoutURL != nil }
    private var displayURL: URL { product.image.cutoutURL ?? product.image.url400 }

    var body: some View {
        Group {
            if hasCutout {
                stagedCard
            } else {
                photoCard
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "In evidenza: \(product.name), \(product.brand)" + (product.soldInItaly ? ", venduto in Italia" : "")
        )
        .accessibilityIdentifier("product.featured.\(product.id)")
        .productContextMenu(for: product)
        .task(id: displayURL) { await load() }
    }

    /// Ritaglio su un palco a tutta larghezza (lo stesso sistema tessera-e-margine delle miniature, in
    /// grande) con marca, badge e titolo sotto: nessuno scrim, testo in colore etichetta.
    private var stagedCard: some View {
        // Palco compatto (150 pt): con 180 pt l'audit di accessibilità non riusciva più a osservare
        // l'intestazione «Creme viso» ingrandita (finiva sotto la piega) e la segnalava come non scalabile.
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(height: 150)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 112)
                    } else if failed {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(product.brand)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                    if product.soldInItaly {
                        ItalyBadge(productID: product.id)
                    }
                }
                Text(product.name)
                    .font(.title2.weight(.bold))
            }
            .foregroundStyle(Color(.label))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
    }

    /// Foto originale a tutta scheda con scrim e testo bianco (quando il ritaglio non esiste).
    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(product.brand)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                if product.soldInItaly {
                    ItalyBadge(productID: product.id, onDark: true)
                }
            }
            Text(product.name)
                .font(.title2.weight(.bold))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 4)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .bottomLeading)
        .background { photo }
    }

    /// Foto originale ritagliata a riempire la scheda con il gradiente in basso; in attesa o senza rete resta
    /// un fondo neutro con l'icona segnaposto.
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
                    colors: [.clear, .black.opacity(Self.scrimOpacity)],
                    startPoint: UnitPoint(x: 0.5, y: Self.scrimStart),
                    endPoint: .bottom
                )
            }
            .clipped()
    }

    private func load() async {
        if let cached = loader.cachedImage(for: displayURL) {
            image = cached
            return
        }
        failed = false
        if let loaded = await loader.image(for: displayURL) {
            image = loaded
        } else {
            image = nil
            failed = true
        }
    }
}
