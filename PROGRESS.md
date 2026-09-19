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

- 2026-09-19: step 3+4 — app SwiftUI (iOS 18, xcodegen, `SkinCareKit` locale): lista per categorie,
  riga con miniatura/titolo/marca/descrizione, attribuzione come prima riga (apre la scheda licenze),
  menu contestuale «Apri su Open Beauty Facts» + credito foto, `ImageLoader` con URLCache, stub di rete
  solo DEBUG via `launchEnvironment`. 8 test UI verdi (righe ≥ 20, immagini `loaded`, refresh remoto
  visibile, offline con placeholder, attribuzione+scheda, menu, audit accessibilità, AX-L) + 2 test
  diagnostici saltati di default (`TEST_RUNNER_SKINCARE_AUDIT_LAB=1`). `scripts/check_done.sh` scritto e
  visto fallire su gauntlet/verificatore. Catture del bar Landmarks in `gauntlet/reference/` (4).

- 2026-09-19: step 5 — gauntlet contro Apple Landmarks (iOS 26), 3 round, critici e builder a contesto
  fresco, confronto cieco. Esiti: **P2 e P3 vinti alla cieca**, P1/P4/P5 a cap con gap residui annotati
  (`gauntlet/LOG.md`). Cambi nati dal loop: card «in evidenza» con testo su gradiente, miniature a riquadro
  fisso con filetto, gerarchia riga (marca piena, descrizione in due righe), attribuzione come ultima riga;
  builder: plausibilità INCI, tokenizer esteso, quantità/marche normalizzate, esclusioni per categoria,
  credito foto dall'endpoint prodotto e dalla lingua dell'URL (crediti generici 0/120).

- 2026-09-19: step 6 — verificatore indipendente a contesto fresco: PASS, 0 difetti bloccanti, 8 note;
  applicate: corsa all'avvio (`refreshIfNeeded` ora attende `load()`, test nel Kit), colore della scheda
  licenze, dicitura P3 nel registro, commento sul `set -uo` di `check_done.sh`.

VERIFICATORE: PASS (2026-09-19, sub-agent a contesto fresco; rapporto in chat, note in questa sezione)

- 2026-09-19: `./scripts/check_done.sh` →
  `DONE=PASS · kit 42 test · builder 66 test · snapshot 120 prodotti · UI 8/10 passati, 0 falliti, 2 saltati · gauntlet vinti 2/5 · remoto n/d · 2026-09-19T15:29:05Z`

## In corso
- Step 7: repo pubblico `Andrew64-bit/SkinCare`, Pages su `/docs`, `REQUIRE_REMOTE=1 ./scripts/check_done.sh`.

## Da fare
- Step 7: repo pubblico `Andrew64-bit/SkinCare`, Pages su `/docs`, verifica `REQUIRE_REMOTE=1`.
- Dopo: gap residui del gauntlet (miniature 4:5 centrate; validazione dizionario INCI completo, es. CosIng;
  ritmo delle righe), schermata dettaglio (App Store 4.2), privacy policy pubblica, mailbox di progetto.

## Decisioni prese
- «Trattamento viso anti-età» nelle descrizioni è il nome della categoria tassonomica OBF
  (`anti-aging-face-care-products`), non un claim dell'app; le descrizioni restano composte solo da campi
  dichiarati (categoria, marca, formato, ingredienti).
- Il recupero dell'autore della foto dall'endpoint prodotto costa fino a una richiesta per prodotto
  (~6,5 s ciascuna, entro i limiti OBF): accettato nel job settimanale, da monitorare.
- Audit di accessibilità: colori espliciti (`Color(.label)` per intestazioni, `label` al 70 % per testi
  attenuati: `secondaryLabel` si ferma a 3,5:1), nessun `lineLimit` (testo tagliato), niente `Label`
  con titolo nascosto in toolbar, niente `ProgressView` nella miniatura, attribuzione come riga e non
  come header/footer di sezione (in una lista lunga l'audit la segnala come testo tagliabile).
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
- Step 0–4 ≤ 35 turni · gauntlet ≤ 25 · verifica+pubblicazione ≤ 10.
- **Sforamento registrato**: gli step 0–4 hanno usato circa 55 turni (≈ 20 oltre il cap), quasi tutti
  nella diagnosi dell'audit di accessibilità (6 cause distinte trovate per bisezione con il lab).
  Decisione: proseguire con i cap delle fasi restanti invariati e riportare lo sforamento nel resoconto.
