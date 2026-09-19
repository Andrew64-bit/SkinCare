# PROGRESS — SkinCare iOS v0.1

Piano approvato il 2026-09-19: `docs/superpowers/specs/2026-09-19-product-list-design.md`.
Prova di completamento: `./scripts/check_done.sh` → `DONE=PASS`.

## Fatto
- 2026-09-19: ricerca (fonte dati OBF, licenze, API, bar Landmarks, toolchain), piano approvato,
  repo inizializzato su `feat/product-list`, fixture OBF reali salvate in
  `Tools/catalog-builder/Tests/CatalogBuilderTests/Fixtures/`.

- 2026-09-19: step 1 — `SkinCareKit` in TDD: modelli, `CatalogCodec` (validazione, dedup, soglia),
  `CatalogStore` (atomico, escluso da backup, corrotto → cancellato), `RemoteCatalogSource` (ETag/304),
  `CatalogRepository` (bundle vs store, refresh giornaliero tutto-o-niente). 31 test verdi, lint pulito.

- 2026-09-19: step 2 — `Tools/catalog-builder` (DTO tolleranti, composer IT, rate limiter, client OBF,
  mapper con filtri, assembler, CLI build/verify) in TDD: 39 test verdi. Catalogo reale generato:
  120 prodotti, 6 categorie × 20, `QUALITY=PASS`, 33 s, 12 richieste a OBF. `BundledCatalog` nel Kit
  con 3 test sullo snapshot (41 test verdi nel Kit). Lint pulito.

## In corso
- Step 3: app (project.yml → xcodegen, viste, ImageLoader, attribuzione, stub rete DEBUG).

## Da fare
- Step 2: `catalog-builder` + generazione `catalog.json` (≥ 60 prodotti).
- Step 3: app (project.yml, viste, ImageLoader, attribuzione, stub rete DEBUG).
- Step 4: test UI + `scripts/check_done.sh` (ogni check visto fallire).
- Step 5: gauntlet P1–P5 (cap 3 round ciascuno) con catture del bar in `gauntlet/reference/`.
- Step 6: verificatore a contesto fresco → `DONE=PASS`.
- Step 7: repo pubblico `Andrew64-bit/SkinCare`, Pages, Action settimanale, URL nell'app.

## Decisioni prese
- Descrizioni sempre in italiano: il nome generico OBF si usa solo se italiano (`generic_name_it` o
  `lang == it`), altrimenti «{categoria} di {marca}». Selezione: nome ≥ 3, marca, foto fronte, INCI con
  ≥ 2 ingredienti riconoscibili (separatori `, ; • · |` a capo; sinonimi «A / B» → A; etichette
  «INGREDIENTS:» rimosse).
- Credito foto: uploader risolto da `images` quando possibile (100/120), altrimenti «contributori
  Open Beauty Facts» con link alla pagina prodotto (attribuzione comunque conforme).
- L'app non chiama Open Beauty Facts: solo il builder (limite 10 ricerche/min per IP, NAT mobile, policy
  uso massivo). L'app legge `catalog.json` (bundle + URL statico con ETag).
- Catalogo statico + pipeline invece di un backend vivo (confermato da Andrea il 2026-09-19); un'API
  futura passa da `CatalogSource`; dati utente futuri → CloudKit privato.
- iOS 18.0 minimo (stesso parco dispositivi di iOS 17), Swift 6, xcodegen, nessuna dipendenza esterna.
- Storage: file JSON in Application Support (atomico, escluso dal backup), non SwiftData.
- Categorie v1: facial-creams, cleansers, sunscreen, face-masks, anti-aging-face-care-products, lip-balms.

## Cap turni (piano)
- Step 0–4 ≤ 35 turni · gauntlet ≤ 25 · verifica+pubblicazione ≤ 10. Turni usati: step 0 in corso.
