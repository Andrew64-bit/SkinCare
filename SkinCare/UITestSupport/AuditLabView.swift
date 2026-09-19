#if DEBUG
import SkinCareKit
import SwiftUI

/// Laboratorio diagnostico per l'audit di accessibilità: mostra un solo componente alla volta,
/// scelto con `SKINCARE_UITEST_LAB=<variante>`, così un'issue senza elemento si può attribuire.
struct AuditLabView: View {
    let variant: String
    let product: Product?
    var products: [Product] = []
    var repository: CatalogRepository?

    private func slice(start: Int, count: Int) -> [Product] {
        let lower = min(max(start, 0), products.count)
        let upper = min(lower + max(count, 0), products.count)
        return Array(products[lower..<upper])
    }

    private func attributionText(flags: String) -> String {
        if flags.contains("S") { return "Dati: Open Beauty Facts (ODbL)" }
        let base = "Dati: Open Beauty Facts (ODbL) · Foto: contributori Open Beauty Facts (CC BY-SA 3.0)"
        let updated = "Catalogo aggiornato il 4 mar 2027"
        return flags.contains("N") ? base + " · " + updated : base + "\n" + updated
    }

    @ViewBuilder
    private func attributionView(flags: String) -> some View {
        let text = Text(attributionText(flags: flags))
            .font(.footnote)
            .foregroundStyle(Color(.label))
        if flags.contains("X") {
            text.fixedSize(horizontal: false, vertical: true)
        } else {
            text
        }
    }

    @ViewBuilder
    private func composed(flags: String) -> some View {
        // flag: h intestazioni · f piè in testa · H attribuzione nella prima intestazione · t toolbar ·
        // r refreshable · X fixedSize verticale · N senza a capo · S testo corto
        let list = List {
            if flags.contains("R") {
                Section {
                    attributionView(flags: flags)
                }
            }
            if flags.contains("f") {
                Section {
                    EmptyView()
                } footer: {
                    attributionView(flags: flags)
                }
            }
            if flags.contains("h") {
                let sections = Array(ProductListView.sections(of: products).enumerated())
                ForEach(sections, id: \.element.category.id) { index, section in
                    Section {
                        ForEach(section.products) { product in ProductRow(product: product) }
                    } header: {
                        VStack(alignment: .leading, spacing: 10) {
                            if flags.contains("H"), index == 0 {
                                attributionView(flags: flags)
                            }
                            Text(section.category.label)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color(.label))
                        }
                        .textCase(nil)
                    }
                }
            } else {
                ForEach(products) { product in ProductRow(product: product) }
            }
        }
        .toolbar {
            if flags.contains("t") {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("Informazioni e licenze")
                }
            }
        }
        if flags.contains("B") {
            list.safeAreaInset(edge: .bottom) {
                attributionView(flags: flags)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        } else if flags.contains("r") {
            list.refreshable {}
        } else {
            list
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch variant {
                case "empty":
                    List { Text("riga") }
                case "toolbar":
                    List { Text("riga") }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {} label: { Image(systemName: "info.circle") }
                                    .accessibilityLabel("Informazioni e licenze")
                            }
                        }
                case "footer":
                    List {
                        Section {
                            EmptyView()
                        } footer: {
                            Text(attributionText(flags: ""))
                                .font(.footnote)
                                .foregroundStyle(Color(.label))
                        }
                        Text("riga")
                    }
                case "header":
                    List {
                        Section {
                            Text("riga")
                        } header: {
                            Text("Creme viso")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color(.label))
                                .textCase(nil)
                        }
                    }
                case "rowtext":
                    List {
                        if let product {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(product.name).font(.headline)
                                Text(product.brand).font(.subheadline).foregroundStyle(ProductRow.mutedText)
                                Text(product.description).font(.footnote).foregroundStyle(ProductRow.mutedText)
                            }
                        }
                    }
                case "image":
                    List {
                        if let product {
                            HStack { ProductImageView(product: product); Text("riga") }
                        }
                    }
                case "refresh":
                    List { Text("riga") }
                        .refreshable {}
                case "row":
                    List {
                        if let product { ProductRow(product: product) }
                    }
                case let range where range.hasPrefix("rows:"):
                    // rows:<start>:<count> — bisezione sulla lista reale.
                    let parts = range.split(separator: ":").compactMap { Int($0) }
                    List {
                        ForEach(slice(start: parts.first ?? 0, count: parts.dropFirst().first ?? 10)) { product in
                            ProductRow(product: product)
                        }
                    }
                case "full":
                    if let repository {
                        ProductListView(repository: repository)
                    }
                case let flags where flags.hasPrefix("compose:"):
                    // compose:<h|f|t|r>* — h intestazioni per categoria, f piè in testa, t toolbar, r refreshable.
                    composed(flags: String(flags.dropFirst("compose:".count)))
                default:
                    Text("variante sconosciuta: \(variant)")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(variant == "notitle" ? "" : "Prodotti")
        }
        .accessibilityIdentifier("lab.ready")
    }
}
#endif
