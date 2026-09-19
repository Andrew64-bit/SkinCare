import SkinCareKit
import SwiftUI

/// Scheda «Informazioni e licenze»: attribuzione richiesta da ODbL / DbCL / CC BY-SA, avvisi su marchi
/// e limiti delle descrizioni, contatto per segnalazioni.
struct AttributionView: View {
    let catalog: Catalog
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Fonte dei dati") {
                    Text("I prodotti provengono da Open Beauty Facts, il database libero e collaborativo dei cosmetici. "
                        + "Contiene informazioni da Open Beauty Facts, rese disponibili sotto la Open Database License (ODbL).")
                    Link("world.openbeautyfacts.org", destination: catalog.source.url)
                }
                Section("Licenze") {
                    Link(destination: URL(string: "https://opendatacommons.org/licenses/odbl/1-0/")!) {
                        licenseRow("Database", "Open Database License (ODbL) v1.0")
                    }
                    Link(destination: URL(string: "https://opendatacommons.org/licenses/dbcl/1-0/")!) {
                        licenseRow("Contenuti", "Database Contents License (DbCL) v1.0")
                    }
                    Link(destination: URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!) {
                        licenseRow(
                            "Foto", "Creative Commons Attribution-ShareAlike 3.0 (CC BY-SA 3.0), © i rispettivi contributori"
                        )
                    }
                    Link(destination: AppConfig.catalogRepositoryURL) {
                        licenseRow("Questo catalogo", "Database derivato, pubblicato a sua volta sotto ODbL v1.0")
                    }
                }
                Section("Marchi e limiti") {
                    Text("Nomi, marchi e confezioni appartengono ai rispettivi proprietari e sono mostrati a solo scopo "
                        + "identificativo. L'app non è affiliata ad alcun marchio né a Open Beauty Facts.")
                    Text("Le descrizioni sono composte dai dati dichiarati (categoria, marca, formato, ingredienti) e non "
                        + "costituiscono consigli medici o cosmetici.")
                }
                Section("Segnalazioni") {
                    Link("Errori o richieste di rimozione: \(AppConfig.supportEmail)",
                         destination: URL(string: "mailto:\(AppConfig.supportEmail)")!)
                }
                Section("Catalogo") {
                    LabeledContent("Prodotti", value: "\(catalog.products.count)")
                    LabeledContent("Generato il", value: catalog.generatedAt.formatted(date: .long, time: .shortened))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("attribution.sheet")
            .navigationTitle("Informazioni e licenze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }

    private func licenseRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
