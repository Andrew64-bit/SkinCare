import SkinCareKit
import SwiftUI

struct ProductListView: View {
    let repository: CatalogRepository
    @State private var showAttribution = false
    @State private var query = ""
    @State private var italyOnly = false

    /// Ricerca locale (nome, marca, categoria, barcode): nessuna chiamata di rete.
    private var visibleProducts: [Product] {
        let base = italyOnly ? repository.catalog.products.filter(\.soldInItaly) : repository.catalog.products
        return ProductSearch.filter(base, query: query)
    }

    private var isSearching: Bool {
        !ProductSearch.normalize(query).isEmpty
    }

    private var sections: [(category: ProductCategory, products: [Product])] {
        Self.sections(of: visibleProducts)
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
                // Primo prodotto del catalogo in evidenza, a tutta larghezza subito sotto il titolo grande
                // (sparisce durante la ricerca: lo spazio va ai risultati).
                if !isSearching, let featured = repository.catalog.products.first {
                    Section {
                        FeaturedProductCard(product: featured)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                }
                if visibleProducts.isEmpty, isSearching || italyOnly {
                    Section {
                        emptySearchState
                    }
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
                // Attribuzione e data del catalogo come ultima riga: obbligo di licenza (ODbL, CC BY-SA), mai
                // rimuoverla; tocca per le licenze. Riga e non intestazione o piè di sezione: in una lista lunga
                // l'audit di accessibilità li segnala come testo tagliato (verificato per bisezione).
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
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Cerca" // breve: un segnaposto lungo viene segnalato dall'audit come tagliabile
            )
            .navigationTitle("Prodotti")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            italyOnly = false
                        } label: {
                            Label("Tutti i prodotti", systemImage: italyOnly ? "circle" : "checkmark.circle.fill")
                        }
                        .accessibilityIdentifier("filter.all")
                        Button {
                            italyOnly = true
                        } label: {
                            Label("Solo venduti in Italia", systemImage: italyOnly ? "checkmark.circle.fill" : "circle")
                        }
                        .accessibilityIdentifier("filter.italy")
                    } label: {
                        Image(systemName: italyOnly
                            ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(italyOnly ? "Filtro: solo venduti in Italia" : "Filtro: tutti i prodotti")
                    .accessibilityIdentifier("filter.menu")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAttribution = true
                    } label: {
                        // Solo icona: il titolo di una Label in una barra resta nascosto e l'audit lo segnala
                        // come testo tagliato.
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Informazioni e licenze")
                    // La data del catalogo anche qui: verificabile senza scorrere fino all'ultima riga.
                    .accessibilityValue(repository.catalog.generatedAt.ISO8601Format())
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

    /// Stato «nessun risultato»: dice quanti prodotti ha il catalogo e come riprovare. Colori espliciti
    /// (regole dell'audit di accessibilità), nessun troncamento.
    private var emptySearchState: some View {
        ContentUnavailableView {
            Label("Nessun prodotto trovato", systemImage: "magnifyingglass")
                .foregroundStyle(Color(.label))
        } description: {
            Text(emptyStateText)
                .foregroundStyle(ProductRow.mutedText)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.empty")
    }

    private var emptyStateText: String {
        let scope = italyOnly
            ? "\(repository.catalog.products.filter(\.soldInItaly).count) prodotti segnalati in vendita in Italia"
            : "\(repository.catalog.products.count) prodotti del catalogo"
        if isSearching {
            return "Nessun risultato per “\(query.trimmingCharacters(in: .whitespaces))” fra i \(scope). "
                + "Prova con la marca o il nome: il catalogo cresce ogni settimana."
        }
        return "Nessun prodotto fra i \(scope)."
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
