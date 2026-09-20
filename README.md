# SkinCare (iOS)

App iOS (SwiftUI, iOS 18+) che mostra un catalogo di prodotti skincare — foto, nome, marca, descrizione —
raggruppati per categoria, con ricerca locale per nome, marca, categoria o barcode (594 prodotti in
8 categorie, fino a 100 per categoria). I prodotti segnalati in vendita in Italia da Open Beauty Facts stanno
in cima con il badge «Venduto in Italia» (filtro «Solo Italia» nella barra); le immagini sono ritagli
automatici del prodotto su sfondo neutro (Vision, nel builder) derivati dalle foto CC BY-SA, con la foto
originale dove il ritaglio non riesce. I dati vengono da [Open Beauty Facts](https://world.openbeautyfacts.org)
attraverso una pipeline offline: l'app **non** interroga mai OBF, legge solo un `catalog.json` di nostra
proprietà (incluso nell'app e pubblicato su GitHub Pages, rigenerato ogni settimana).

## Struttura

| Percorso | Cosa |
|---|---|
| `SkinCare/` | app (viste, `ImageLoader`, wiring); `SkinCare.xcodeproj` è generato da `project.yml` con xcodegen |
| `Packages/SkinCareKit/` | modelli, codec con validazione, store atomico, sorgente remota (ETag), repository, snapshot `Resources/catalog.json` |
| `Tools/catalog-builder/` | client OBF (rate limit, User-Agent), mapper con filtri di plausibilità, composer delle descrizioni, ritaglio immagini (Vision) con manifest incrementale, CLI `build`/`verify` |
| `SkinCareUITests/` | test UI (righe, immagini, refresh remoto stubbato, offline, attribuzione, audit di accessibilità, Dynamic Type) |
| `scripts/check_done.sh` | prova di completamento: stampa `DONE=PASS` solo se tutte le verifiche passano |
| `gauntlet/` | loop di qualità contro il sample Apple Landmarks: catture di riferimento, round, `LOG.md` |
| `docs/` | GitHub Pages: `catalog/catalog.json` pubblico, `images/<barcode>.png` (ritagli, CC BY-SA) + nota di licenza |
| `.github/workflows/catalog.yml` | rigenerazione settimanale del catalogo (read-only verso OBF, gate di qualità) |

## Sviluppo

```bash
xcodegen generate                      # progetto Xcode da project.yml
(cd Packages/SkinCareKit && swift test)
(cd Tools/catalog-builder && swift test)
(cd Tools/catalog-builder && swift run -c release catalog-builder build --out ../../Packages/SkinCareKit/Sources/SkinCareKit/Resources/catalog.json)
./scripts/check_done.sh                # tutto, incluso xcodebuild test su iPhone 17 Pro / iOS 26.2
```

## Licenze

Codice: MIT (`LICENSE`). Catalogo: database derivato da Open Beauty Facts, ODbL 1.0 / DbCL 1.0; foto
CC BY-SA 3.0 dei rispettivi contributori (`LICENSE-CATALOG.md`). Marchi e confezioni appartengono ai
rispettivi proprietari; l'app non è affiliata ad alcun marchio né a Open Beauty Facts e non fornisce
consigli medici.
