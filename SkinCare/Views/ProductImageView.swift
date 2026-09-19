import SkinCareKit
import SwiftUI

/// Miniatura del prodotto: un riquadro 72×72 identico per ogni riga (foto ritagliata a riempire, angoli
/// continui, fondo `secondarySystemFill` visibile anche sulla card bianca), così le foto con sfondi e
/// proporzioni diverse non sporcano la riga. Lo stato (`loading` / `loaded` / `placeholder`) è esposto come
/// valore di accessibilità sull'intero riquadro, così i test UI possono verificare che l'immagine sia comparsa.
struct ProductImageView: View {
    enum Phase: String {
        case loading, loaded, placeholder
    }

    static let side: CGFloat = 72

    let product: Product
    @Environment(ImageLoader.self) private var loader
    @State private var phase: Phase = .loading
    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemFill)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
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
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
            .accessibilityLabel("Foto di \(product.name)")
            .accessibilityIdentifier("image.\(product.id)")
            .accessibilityValue(phase.rawValue)
            .task(id: product.image.url200) {
                if let cached = loader.cachedImage(for: product.image.url200) {
                    image = cached
                    phase = .loaded
                    return
                }
                phase = .loading
                if let loaded = await loader.image(for: product.image.url200) {
                    image = loaded
                    phase = .loaded
                } else {
                    image = nil
                    phase = .placeholder
                }
            }
    }
}
