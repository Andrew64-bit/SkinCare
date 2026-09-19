# Piano — SkinCare iOS v0.1: lista prodotti skincare (gauntlet loop)

## Contesto

Andrea vuole un'app iOS per la skincare. Prima tappa: **una sola schermata** con la lista di prodotti
skincare (foto, nome, marca, descrizione). Vincoli: sistema **affidabile e durevole**, dati **in
aggiornamento costante**, tutto **per vie legali**, lavoro condotto con il **gauntlet loop** (la tua
skill in `MyMobileApp/.claude/skills/gauntlet-loop/SKILL.md`: bar reale e recuperabile, pezzi piccoli,
builder ≠ critico severo a contesto fresco, confronto alla cieca, loop finché il critico sceglie la
nostra; con il cap sui round che il CLAUDE.md impone).

`Desktop/SkinCare` è vuota, non è un repo git. Ricerca fatta oggi (nessun codice scritto):

| Cosa | Esito verificato |
|---|---|
| Toolchain | Xcode 26.2 (17C52), Swift 6.2.3, simulatori iOS 17.5/18.6/26.2, iPhone 17 Pro, xcodegen 2.46, swiftlint 0.65, `gh` autenticato come Andrew64-bit |
| Fonte dati legale | **Open Beauty Facts** (OBF): DB in ODbL 1.0 + DbCL 1.0, foto CC BY-SA 3.0, attribuzione con link obbligatoria, share-alike sui DB derivati; API v2 viva (200 in 0,3 s) |
| Qualità dati | `facial creams` top-100 per popolarità: 80 con nome+marca+foto, 69 con INCI, 11 con descrizione → la descrizione va **composta** dai campi strutturati; uploader della foto ricavabile in 79/80 |
| Categorie (n. prodotti) | facial-creams 465 · sunscreen 603 · cleansers 308 · face-masks 134 · anti-aging-face-care-products 113 · lip-balms 315 (serums: 2, scartato) |
| Regole API OBF | 10 ricerche/min/**IP**, 15 letture/min/IP, User-Agent `App/Versione (contatto)` obbligatorio, `page_size` max 100; uso massivo → export JSONL (99 MB gz) o backend proprio |
| CDN immagini | `Cache-Control: max-age=864000` + `ETag` → la cache HTTP standard basta |
| Bar del gauntlet | Sample Apple **Landmarks (iOS 26, Liquid Glass)**: zip ufficiale scaricabile (336 MB, 22 giu 2026), compilabile con Xcode 26 sullo stesso simulatore |
| API di test | `performAccessibilityAudit` presente nell'SDK (iOS 17+), `XCTApplicationLaunchMetric` presente |
| Progetto precedente | `Desktop/skincare-discovery` (discovery Reddit Italia): contesto utile, non fonte dati |

Una critica indipendente (sub-agent a contesto fresco) ha fatto cambiare un punto chiave: **l'app non
deve chiamare OBF**. Il limite è per IP e dietro al NAT degli operatori mobili centinaia di utenti
condividono un IPv4: i refresh andrebbero in 429 dal primo giorno, e per la policy OBF il fan-out da
molti dispositivi è uso massivo. Quindi: il builder (macOS/CI) interroga OBF; l'app legge **solo** un
`catalog.json` di nostra proprietà (nel bundle + pubblicato su un URL statico).

## Decisioni prese (approvando il piano le confermi; dimmi se ne vuoi cambiare una)

1. **Bar del gauntlet: A) Landmarks di Apple** (lista, compilata dal sample ufficiale e catturata sullo
   stesso simulatore iPhone 17 Pro / iOS 26.2, chiaro+scuro, testo standard e AX-L). Alternative
   scartate: B) lista prodotti di Yuka (solo screenshot marketing, poco confrontabili); C) app Sephora IT
   (idem, più rischio di ricalcare un trade dress commerciale).
2. **Fonte dati: Open Beauty Facts** via builder, con attribuzione in-app (licenze + link) e User-Agent
   `SkinCareCatalogBuilder/0.1 (vannozziandrea@gmail.com)` (costante configurabile). Niente scraping di
   brand/retailer, niente foto prese dal web.
3. **Pubblicazione del catalogo — repo GitHub pubblico `Andrew64-bit/SkinCare`** (tutto il progetto:
   app + kit + builder + `catalog.json`; codice MIT, catalogo ODbL). Motivi: l'ODbL richiede comunque di
   rendere pubblico il DB derivato (§4.6) e GitHub Pages serve il JSON con `ETag` a costo zero; un solo
   repo evita di duplicare lo schema fra builder e app. Una GitHub Action **settimanale** rigenera il
   catalogo (read-only verso OBF, poche richieste, entro i limiti). Il repo viene creato **solo dopo la
   tua approvazione di questo piano**, come ultimo passo. Alternative: (b) app privata + repo pubblico
   solo dati con builder autonomo (schema in due posti); (c) nessuna pubblicazione ora → refresh
   disattivato, solo snapshot nel bundle (non «in aggiornamento costante»).
4. **Aggiornamento in-app**: snapshot nel bundle (offline e primo avvio) + `RemoteCatalogSource` che fa
   una GET condizionale (`If-None-Match`) all'URL pubblico una volta al giorno; sostituzione atomica solo
   se il documento decodifica, ha `schemaVersion` compatibile e ≥ 50 prodotti validi.
   **Confermato da Andrea (2026-09-19) al posto di un backend vivo**: la pipeline è il backend, gira
   offline e pubblica un artefatto immutabile; l'app dipende da `CatalogSource`, quindi un'API futura
   (ricerca full-text su tutto OBF, account, curatela web) è una modifica contenuta. Per i dati
   dell'utente, quando arriveranno, la via è CloudKit privato: il catalogo può restare statico.
5. **Stack**: SwiftUI, **iOS 18.0** minimo (stesso parco dispositivi di iOS 17, in più `Mutex`), Swift 6,
   progetto generato da **xcodegen**, package `SkinCareKit` solo Foundation, builder in un package
   separato, Swift Testing + XCUITest, SwiftLint. Nessuna dipendenza esterna.
6. **UI in italiano**; nomi prodotto come nella fonte. Nome app «SkinCare», bundle id
   `com.andreavannozzi.SkinCare`.
7. **Git**: `git init` subito, branch `feat/product-list`; push solo nel passo finale (decisione 3).

## Architettura

```
SkinCare/
├── project.yml                        # xcodegen → SkinCare.xcodeproj (committato, mai editato a mano)
├── Packages/SkinCareKit/              # solo Foundation: gira in `swift test` su macOS senza modifiche
│   ├── Package.swift                  # tools 6.0, platforms iOS 18 / macOS 15
│   ├── Sources/SkinCareKit/
│   │   ├── Catalog.swift, Product.swift, ProductCategory.swift   # Codable+Sendable, schemaVersion 1
│   │   ├── CatalogDecoding.swift      # decode + regole di validità + conteggio minimo (rifiuta schemi futuri)
│   │   ├── BundledCatalog.swift       # carica Resources/catalog.json via Bundle.module
│   │   ├── CatalogStore.swift         # Application Support, scrittura atomica, escluso da backup, file corrotto → cancella e torna al bundle
│   │   ├── RemoteCatalogSource.swift  # GET condizionale con ETag, URLSession iniettabile
│   │   └── CatalogRepository.swift    # bundle → store → refresh giornaliero, tutto-o-niente
│   ├── Sources/SkinCareKit/Resources/catalog.json
│   └── Tests/SkinCareKitTests/ (+ Fixtures/)
├── Tools/catalog-builder/             # package macOS separato, dipende dal Kit via `path:`
│   ├── Sources/catalog-builder/ main.swift, OBFClient.swift, OBFDTO.swift (decode tollerante di `images`),
│   │                             OBFMapper.swift, DescriptionComposer.swift, RateLimiter.swift
│   └── Tests/ (fixture JSON reali catturate oggi)
├── SkinCare/                          # app target (iOS 18)
│   ├── SkinCareApp.swift, AppEnvironment.swift (wiring, launchEnvironment di test, stub URLProtocol solo DEBUG)
│   ├── Views/ ProductListView.swift, ProductRow.swift, ProductImageView.swift, AttributionView.swift
│   ├── ImageLoader.swift              # URLSession + URLCache 200 MB, stato loading/loaded/placeholder
│   └── Resources/ Assets.xcassets, Localizable.xcstrings, PrivacyInfo.xcprivacy, UITestFixtures/ (solo Debug)
├── SkinCareUITests/ProductListUITests.swift
├── scripts/ check_done.sh, boot_sim.sh, capture.sh
├── gauntlet/ README.md, LOG.md, blind.sh, reference/ (catture Landmarks), rounds/
├── .github/workflows/catalog.yml      # settimanale: builder → catalog.json → Pages (solo se decisione 3)
├── docs/superpowers/specs/2026-09-19-product-list-design.md
├── PROGRESS.md, CLAUDE.md (regole del repo), LICENSE (MIT), LICENSE-CATALOG (ODbL), .gitignore, .swiftlint.yml
```

**Flusso dati**: builder (macOS/CI) → OBF API (≤ 1 richiesta / 6,5 s, 6 categorie × 1–2 pagine) →
filtri qualità → `catalog.json` (nel Kit e su GitHub Pages) → app: `CatalogRepository` carica lo store
se valido, altrimenti il bundle → lista visibile subito → se `generatedAt`/ultimo controllo > 24 h,
`RemoteCatalogSource` fa la GET condizionale in background → 304: nulla; 200: decode + validazione +
soglia → `CatalogStore` sostituisce atomicamente → la lista si aggiorna. Errori silenziosi in UI (resta
l'ultimo catalogo buono), piè di lista «Aggiornato il …».

**Schema `catalog.json` v1**: `Catalog { schemaVersion, generatedAt, source { name, url, license,
attribution }, products[] }`, `Product { id (barcode), name, brand, category (enum stabile + etichetta
IT), quantity?, description, ingredientsPreview?, image { url400, url200, credit { uploader, license,
sourceURL } }, sourceURL (pagina OBF), lastModified }`.

**Selezione prodotti** (solo builder): 6 categorie sopra; ordine `unique_scans_n` poi
`last_modified_t`; filtri: nome ≥ 3 caratteri, marca, foto fronte, almeno uno fra INCI e nome generico;
dedup per barcode; top 20 per categoria → circa 100–120 prodotti. Provo anche
`states_tags=en:front-photo-selected,en:brands-completed` per alzare la resa (da verificare).

**Descrizione composta** (`DescriptionComposer`, testato, in italiano): nome generico se presente
(it > en > fr), altrimenti «{Etichetta categoria} di {marca}» + «, {quantità}» + «. Ingredienti
principali: {primi 4 INCI}». Mai claim di efficacia o medici.

**Immagini**: `ImageLoader` proprio (non `AsyncImage`: usa solo `URLSession.shared`, niente retry, un
load cancellato dallo scroll resta in errore), `URLCache` 200 MB, 200 px in lista, «loaded» solo dopo
`UIImage(data:)` riuscito, `accessibilityIdentifier("image.<barcode>")` + `accessibilityValue(stato)`
sull'`Image` stessa (non combinata con la riga).

**Attribuzione legale in-app**: piè di lista «Dati: Open Beauty Facts (ODbL) · Foto: contributori OBF
(CC BY-SA 3.0)»; scheda `AttributionView` con avviso ODbL §4.3, testi/link delle licenze, link al repo
pubblico del catalogo (share-alike §4.6), «marchi e confezioni appartengono ai rispettivi proprietari;
app non affiliata ad alcun brand; nessun consiglio medico», contatto per rimozioni. Menu contestuale su
ogni riga: «Apri su Open Beauty Facts» (attribuzione per prodotto) e «Foto: <uploader>, CC BY-SA 3.0».
`PrivacyInfo.xcprivacy` senza tracking né API a motivazione obbligatoria (niente UserDefaults: l'ultimo
controllo vive nel file dello store).

## Protocollo gauntlet (dopo che l'app compila e i test passano)

- **Bar recuperato davvero**: scarico lo zip Landmarks nello scratchpad, compilo sullo stesso
  simulatore, catturo la lista in 4 condizioni (chiaro/scuro × standard/AX-L) → `gauntlet/reference/`
  **nel repo** (lezione 2026-09-12: lo scratchpad si cancella).
- **Pezzi giudicabili da soli**: P1 riga (foto, titolo, marca, descrizione) · P2 struttura lista e
  chrome (titolo, sezioni, spaziature, stato di caricamento/vuoto) · P3 modalità scura + Dynamic Type
  AX-L (con controllo geometrico: titolo della prima riga interamente dentro la riga e lo schermo) · P4
  immagini (aspect, sfondo, placeholder) · P5 qualità dati (non visivo: il critico campiona 10 prodotti
  del catalogo e li confronta con la pagina OBF: nome, marca, foto coerenti, descrizione non fuorviante).
- **Builder e critico separati**, sub-agent a contesto fresco. `gauntlet/blind.sh` copia le due catture
  come `A.png`/`B.png` con assegnazione casuale scritta in un file che il critico non legge; il critico
  risponde solo `{winner: A|B, biggest_gap: "…"}`; l'orchestratore risolve la mappa.
- **Uscita per pezzo**: il critico sceglie la nostra alla cieca, **oppure cap di 3 round** (CLAUDE.md §6).
  Ogni round in `gauntlet/LOG.md` con verdetto, gap, valori esatti prima/dopo, catture in
  `gauntlet/rounds/` (committate). Il «gap più grande» è l'unica cosa che il builder tocca nel round dopo.

## Definition of Done (verificabile da macchina)

`scripts/check_done.sh` stampa `DONE=PASS` **solo se** tutte queste condizioni sono vere nello stesso run
(`set -euo pipefail`, esiti letti da `xcrun xcresulttool get test-results summary`):

1. `xcodegen generate` ok e `swiftlint --strict` senza violazioni.
2. `swift test` in `Packages/SkinCareKit` verde: decode/validazione (rifiuto schema futuro, prodotto
   senza foto, catalogo sotto soglia), store atomico + file corrotto → bundle, repository (304 → nessun
   cambio; 200 valido → sostituzione; 200 invalido → resta il vecchio) con `URLProtocol` finto; e il
   test sullo **snapshot incluso**: ≥ 60 prodotti, ≥ 5 categorie, 100 % con foto+nome+marca,
   descrizione ≥ 40 caratteri, blocco licenza, nessun duplicato.
3. `swift test` in `Tools/catalog-builder` verde: mapper su fixture reali, composer, rate limiter,
   decodifica tollerante di `images`, risoluzione dell'uploader.
4. `xcodebuild test` (iPhone 17 Pro, OS=26.2, `-parallel-testing-enabled NO`) verde, con test UI:
   con rete stubbata (`SKINCARE_UITEST=1`, fixture nel bundle dell'app, animazioni spente) la lista ha
   ≥ 20 righe e le prime 3 immagini raggiungono `value == "loaded"`, e un catalogo remoto stubbato più
   nuovo fa comparire il suo `generatedAt` nel piè; con `SKINCARE_UITEST_NETWORK=deny` restano ≥ 20 righe
   dal bundle con placeholder e nessun crash; piè di attribuzione e scheda presenti; menu contestuale con
   il link OBF; `performAccessibilityAudit` senza problemi non giustificati; con
   `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL` la prima riga è dentro lo
   schermo e il titolo dentro la riga (geometria).
5. `gauntlet/LOG.md` ha per ognuno dei 5 pezzi «nostra scelta alla cieca» o «cap 3 round (gap residuo:
   …)», e `gauntlet/reference/` contiene le 4 catture del bar.
6. Sub-agent **verificatore** (contesto fresco) ha rivisto il diff contro questo piano e il CLAUDE.md:
   `PASS` registrato in `PROGRESS.md`.
7. Se la decisione 3 è confermata: `curl -sI <URL Pages>/catalog.json` → 200 con `ETag`, e l'app senza
   stub mostra «Aggiornato il …» dopo il refresh (cattura in `gauntlet/rounds/final/`).

Ogni controllo nuovo viene **fatto fallire apposta** una volta prima di fidarsene (lezione 2026-09-12).

## Passi di esecuzione

0. `git init`, `.gitignore`, spec di design, `PROGRESS.md`, `CLAUDE.md` del repo (xcodegen è la fonte
   del progetto; rate limit OBF solo nel builder; simulatore da ribootare dopo `xcodebuild test`;
   `launchEnvironment` non argomenti con trattino), licenze, primo commit su `feat/product-list`.
1. `SkinCareKit` in TDD (test rossi → verdi): modelli, decode/validazione, store, remote source,
   repository. Commit.
2. `catalog-builder` in TDD con fixture reali: client OBF, DTO tolleranti, mapper, composer, rate
   limiter; poi esecuzione vera → `catalog.json` (≥ 60 prodotti); test del Kit sullo snapshot. Commit.
3. App: `project.yml` → progetto, wiring, viste, `ImageLoader`, attribuzione, stub di rete DEBUG;
   build verde; primo avvio nel simulatore con cattura. Commit.
4. Test UI + `scripts/check_done.sh`; ogni check visto fallire. Commit.
5. Gauntlet: catture del bar → P1…P5, max 3 round ciascuno, log. Commit a ogni round.
6. Verificatore a contesto fresco → correzioni → `check_done.sh` → `DONE=PASS` in `PROGRESS.md`.
7. Solo con decisione 3: `gh repo create Andrew64-bit/SkinCare --public`, push, Pages su `/docs`
   (Action che copia `catalog.json` in `docs/catalog/`), URL impostato nell'app, verifica punto 7,
   commit finale.

## Guardrail

- **Cap turni**: passi 0–4 ≤ 35 turni, gauntlet ≤ 25, verifica+pubblicazione ≤ 10; superato un cap mi
  fermo e riporto lo stato in `PROGRESS.md`. Ogni pezzo del gauntlet ≤ 3 round.
- Non tocco nulla fuori da `Desktop/SkinCare` e dallo scratchpad; nessun `push --force`, nessun segreto,
  nessuna cancellazione di massa. Lo zip Apple (336 MB) resta nello scratchpad; nel repo solo le catture.
- Verso OBF: solo API documentate, User-Agent identificativo, ≤ 1 richiesta / 6,5 s, nessun download
  massivo in questa fase.
- La verifica non rompe ciò che verifica: `check_done.sh` scrive solo in `build/` (gitignored), cancella
  il `.xcresult` precedente, e `scripts/boot_sim.sh` (boot + `bootstatus -b`) precede ogni cattura.
- Per scelte architetturali o distruttive non previste qui mi fermo e chiedo.

## Verifica finale end-to-end

```bash
cd /Users/andreavannozzi/Desktop/SkinCare && ./scripts/check_done.sh
```
Atteso: ultima riga `DONE=PASS` con i contatori (test Kit/builder/UI, prodotti nello snapshot, pezzi del
gauntlet vinti/cap, stato del catalogo remoto). In più: app aperta nel pannello iOS Simulator con la lista
scorrevole, e cattura finale accanto al bar in `gauntlet/rounds/final/`.

## Fuori perimetro (prossimi passi)

Schermata dettaglio (utile anche per la linea guida App Store 4.2 «funzionalità minima»), ricerca e
filtri, preferiti, privacy policy pubblica (obbligatoria per l'App Store: dichiara che le foto vengono
caricate dai server OBF), localizzazione inglese, firma/TestFlight, mailbox di progetto per lo User-Agent.
