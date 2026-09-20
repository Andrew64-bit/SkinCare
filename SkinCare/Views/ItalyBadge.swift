import SwiftUI

/// Capsula «Venduto in Italia»: colori espliciti (audit di accessibilità), nessun troncamento.
/// `onDark` = sopra una foto con scrim scuro (testo bianco).
struct ItalyBadge: View {
    let productID: String
    var onDark = false

    var body: some View {
        Label("Venduto in Italia", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(onDark ? .white : Color(.label))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(onDark ? Color.white.opacity(0.22) : Color(.tertiarySystemFill), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Venduto in Italia")
            .accessibilityIdentifier("product.badge.italy.\(productID)")
    }
}
