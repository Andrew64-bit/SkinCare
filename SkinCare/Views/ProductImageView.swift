import SkinCareKit
import SwiftUI

/// Miniatura del prodotto. Lo stato (`loading` / `loaded` / `placeholder`) è esposto come valore di
/// accessibilità sull'intero riquadro, così i test UI possono verificare che l'immagine sia comparsa.
struct ProductImageView: View {
    enum Phase: String {
        case loading, loaded, placeholder
    }

    let product: Product
    @Environment(ImageLoader.self) private var loader
    @State private var phase: Phase = .loading
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else if phase == .placeholder {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                // Nessun ProgressView: un indicatore dentro un riquadro a misura fissa viene letto
                // dall'audit come testo tagliabile; un riquadro neutro basta per una miniatura.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .padding(14)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
