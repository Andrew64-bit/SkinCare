import SkinCareKit
import SwiftUI

/// Miniatura del prodotto: una tessera 72×72 identica per ogni riga — foto ritagliata a riempire, angoli
/// continui, fondo `tertiarySystemFill` e un bordo sottile `separator` che la delimita — così una foto quasi
/// bianca non si scioglie nella card bianca e una foto scura non diventa un blocco pesante. Lo stato
/// (`loading` / `loaded` / `placeholder`) è esposto come valore di accessibilità sull'intero riquadro, così
/// i test UI possono verificare che l'immagine sia comparsa.
struct ProductImageView: View {
    enum Phase: String {
        case loading, loaded, placeholder
        /// Ritaglio del prodotto su trasparente (derivato CC BY-SA, stesso credito della foto).
        case loadedCutout = "loaded:cutout"
    }

    static let side: CGFloat = 72

    let product: Product
    @Environment(ImageLoader.self) private var loader
    @State private var phase: Phase = .loading
    @State private var image: UIImage?
    @Environment(\.colorScheme) private var colorScheme

    /// URL da mostrare: il ritaglio quando esiste, altrimenti la foto originale a 200 px.
    private var displayURL: URL { product.image.cutoutURL ?? product.image.url200 }

    /// Fondo della tessera: bianco in chiaro per i ritagli (sfondo bianco chiesto da Andrea), riempimento
    /// di sistema in scuro e per le foto originali.
    private var tileBackground: Color {
        product.image.cutoutURL != nil && colorScheme == .light ? .white : Color(.tertiarySystemFill)
    }

    var body: some View {
        tileBackground
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: product.image.cutoutURL != nil ? .fit : .fill)
                } else if phase == .placeholder {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                // In caricamento resta il solo fondo neutro: nessun ProgressView (un indicatore dentro un
                // riquadro a misura fissa viene letto dall'audit come testo tagliabile).
            }
            .frame(width: Self.side, height: Self.side)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
            .accessibilityLabel("Foto di \(product.name)")
            .accessibilityIdentifier("image.\(product.id)")
            .accessibilityValue(phase.rawValue)
            .task(id: displayURL) {
                // Ritaglio quando esiste (stato «loaded:cutout»), altrimenti la foto originale («loaded»).
                let loadedPhase: Phase = product.image.cutoutURL != nil ? .loadedCutout : .loaded
                if let cached = loader.cachedImage(for: displayURL) {
                    image = cached
                    phase = loadedPhase
                    return
                }
                phase = .loading
                if let loaded = await loader.image(for: displayURL) {
                    image = loaded
                    phase = loadedPhase
                } else {
                    image = nil
                    phase = .placeholder
                }
            }
    }
}
