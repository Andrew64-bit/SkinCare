import SkinCareKit
import SwiftUI

struct ProductListView: View {
    let repository: CatalogRepository
    @State private var showAttribution = false

    private var sections: [(category: ProductCategory, products: [Product])] {
        Self.sections(of: repository.catalog.products)
    }

    /// Raggruppa per categoria conservando l'ordine del catalogo (le categorie compaiono nell'ordine del builder).
    static func sections(of products: [Product]) -> [(category: ProductCategory, products: [Product])] {
        var order: [String] = []
        var grouped: [String: (ProductCategory, [Product])] = [:]
        for product in products {
            if grouped[product.category.id] == nil {
                order.append(product.category.id)
                grouped[product.category.id] = (product.category, [])
            }
            grouped[product.category.id]?.1.append(product)
        }
        return order.compactMap { grouped[$0] }.map { (category: $0.0, products: $0.1) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Attribuzione e data del catalogo come prima riga: sempre visibile all'avvio e tocca per le
                // licenze. (Come intestazione o piè di sezione l'audit la segnalava come testo tagliato.)
                Section {
                    Button {
                        showAttribution = true
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(ProductRow.mutedText)
                                .accessibilityHidden(true)
                            attribution
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("catalog.attribution")
                    .accessibilityValue(repository.catalog.generatedAt.ISO8601Format())
                    .accessibilityHint("Apre le informazioni sulle fonti e le licenze")
                }
                ForEach(sections, id: \.category.id) { section in
                    Section {
                        ForEach(section.products) { product in
                            ProductRow(product: product)
                        }
                    } header: {
                        // Colore esplicito: l'intestazione grigia di sistema non supera l'audit di contrasto.
                        Text(section.category.label)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(.label))
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Prodotti")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAttribution = true
                    } label: {
                        // Solo icona: il titolo di una Label in una barra resta nascosto e l'audit lo segnala
                        // come testo tagliato.
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Informazioni e licenze")
                    .accessibilityIdentifier("attribution.button")
                }
            }
            .sheet(isPresented: $showAttribution) {
                AttributionView(catalog: repository.catalog)
            }
            .refreshable {
                _ = await repository.refresh()
            }
            .task {
                await repository.load()
                _ = await repository.refreshIfNeeded()
            }
        }
    }

    private var attribution: some View {
        Text(attributionText)
            .font(.footnote)
            .foregroundStyle(ProductRow.mutedText)
    }

    private var attributionText: String {
        let updated = repository.catalog.generatedAt.formatted(date: .abbreviated, time: .omitted)
        return "Dati: Open Beauty Facts (ODbL) · Foto: contributori Open Beauty Facts (CC BY-SA 3.0)\n"
            + "Catalogo aggiornato il \(updated)"
    }
}
