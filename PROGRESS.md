# PROGRESS — SkinCare iOS v0.1

Piano approvato il 2026-09-19: `docs/superpowers/specs/2026-09-19-product-list-design.md`.
Prova di completamento: `./scripts/check_done.sh` → `DONE=PASS`.

## Fatto
- 2026-09-19: ricerca (fonte dati OBF, licenze, API, bar Landmarks, toolchain), piano approvato,
  repo inizializzato su `feat/product-list`, fixture OBF reali salvate in
  `Tools/catalog-builder/Tests/CatalogBuilderTests/Fixtures/`.

## In corso
- Step 1: `SkinCareKit` in TDD (modelli, decode/validazione, store, remote source, repository).

## Da fare
- Step 2: `catalog-builder` + generazione `catalog.json` (≥ 60 prodotti).
- Step 3: app (project.yml, viste, ImageLoader, attribuzione, stub rete DEBUG).
- Step 4: test UI + `scripts/check_done.sh` (ogni check visto fallire).
- Step 5: gauntlet P1–P5 (cap 3 round ciascuno) con catture del bar in `gauntlet/reference/`.
- Step 6: verificatore a contesto fresco → `DONE=PASS`.
- Step 7: repo pubblico `Andrew64-bit/SkinCare`, Pages, Action settimanale, URL nell'app.

## Decisioni prese
- L'app non chiama Open Beauty Facts: solo il builder (limite 10 ricerche/min per IP, NAT mobile, policy
  uso massivo). L'app legge `catalog.json` (bundle + URL statico con ETag).
- Catalogo statico + pipeline invece di un backend vivo (confermato da Andrea il 2026-09-19); un'API
  futura passa da `CatalogSource`; dati utente futuri → CloudKit privato.
- iOS 18.0 minimo (stesso parco dispositivi di iOS 17), Swift 6, xcodegen, nessuna dipendenza esterna.
- Storage: file JSON in Application Support (atomico, escluso dal backup), non SwiftData.
- Categorie v1: facial-creams, cleansers, sunscreen, face-masks, anti-aging-face-care-products, lip-balms.

## Cap turni (piano)
- Step 0–4 ≤ 35 turni · gauntlet ≤ 25 · verifica+pubblicazione ≤ 10. Turni usati: step 0 in corso.
