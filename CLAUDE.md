# CLAUDE.md — SkinCare (app iOS)

Le regole generali di metodo stanno in `../CLAUDE.md` (loop engineering). Qui solo ciò che è specifico
di questo repo. Il piano approvato e la definition of done sono in
`docs/superpowers/specs/2026-09-19-product-list-design.md`; lo stato vive in `PROGRESS.md`.

## Struttura e comandi
- `project.yml` è la fonte del progetto Xcode: **mai modificare `SkinCare.xcodeproj` a mano**, rigenerare
  con `xcodegen generate`.
- `Packages/SkinCareKit`: solo Foundation (niente UIKit/SwiftUI) così `swift test` gira su macOS.
  Contiene modelli, decodifica/validazione, store, sorgente remota, repository e lo snapshot
  `Resources/catalog.json`.
- `Tools/catalog-builder`: package macOS separato che interroga Open Beauty Facts e scrive `catalog.json`.
  È l'**unico** codice che parla con OBF: User-Agent identificativo, ≤ 1 richiesta ogni 6,5 s, `page_size`
  ≤ 100. L'app non chiama mai OBF (limite per IP, NAT mobile, policy sull'uso massivo).
- Prova di completamento: `./scripts/check_done.sh` deve stampare `DONE=PASS`. Non dichiarare mai
  finito un lavoro senza incollare quella riga.

## Test
- Unit: Swift Testing (`swift test` nei due package). UI: XCUITest su iPhone 17 Pro, iOS 26.2,
  `-parallel-testing-enabled NO`.
- Le modalità di test dell'app si attivano con **`launchEnvironment`**, non con argomenti col trattino
  (`-x -y` viene letto da NSArgumentDomain come coppia chiave/valore): `SKINCARE_UITEST=1` (store
  isolato + rete stubbata con fixture nel bundle dell'app), `SKINCARE_UITEST_NETWORK=deny`.
- `xcodebuild test` spegne il simulatore a fine corsa: prima di una cattura eseguire
  `scripts/boot_sim.sh` (boot + `bootstatus -b`).
- Ogni check nuovo va **visto fallire** una volta prima di fidarsene.

## Legale (non negoziabile)
- Dati solo da Open Beauty Facts via builder; niente scraping di brand/retailer, niente foto dal web.
- Attribuzione in-app sempre presente (ODbL + CC BY-SA 3.0 + link); il catalogo derivato resta pubblico
  (`LICENSE-CATALOG.md`). Nessun claim medico o di efficacia nelle descrizioni.

## Gauntlet
- Bar: sample Apple Landmarks (iOS 26) compilato sullo stesso simulatore; catture in `gauntlet/reference/`.
- Builder ≠ critico (sub-agent a contesto fresco), confronto alla cieca via `gauntlet/blind.sh`,
  un solo «gap più grande» per round, cap 3 round per pezzo, tutto in `gauntlet/LOG.md`.

## Lezioni apprese
- 2026-09-19 (lint del Kit): `swiftlint ... | tail` ha restituito exit 0 con 5 violazioni, e il commit è
  passato "pulito". Regola: un comando di verifica non va mai messo in pipe senza `set -o pipefail`
  (o si legge `${pipestatus[1]}` in zsh); negli script di check usare `set -euo pipefail` e nessuna pipe
  sulle righe che decidono l'esito.
- 2026-09-19 (builder del gauntlet): un sub-agent che lancia comandi in background può «finire» (notifica),
  poi risvegliarsi da solo alla fine del suo comando e continuare a modificare file e usare il simulatore
  mentre l'orchestratore ha già ripreso il checkout: due `xcodebuild test` concorrenti sono crollati e un
  mio edit è saltato perché il file era cambiato sotto. Regola: prima di toccare il checkout dopo il
  ritorno di un builder, fermarlo esplicitamente (`TaskStop`) e verificare `pgrep -f xcodebuild`; nei
  prompt dei builder vietare i comandi in background.
- 2026-09-19 (commit su run rosso): il commit era condizionato a `grep -q "passed after" log`, ma quella
  stringa la stampa OGNI singolo test verde, quindi la condizione era vera anche con un test fallito e ho
  committato un run rosso. Regola: l'esito di un comando di verifica si legge SOLO dal suo exit code salvato
  in una variabile (`swift test …; TEST=$?`), mai da un grep sul log; il log serve solo a mostrare i dettagli.
- 2026-09-19 (segfault fantasma in `verify`): dopo aver aggiunto due campi a `CatalogQualityReport` nel Kit,
  il binario del builder è crollato (`EXC_BAD_ACCESS` iterando `issues`) perché la sua `.build/` conservava
  oggetti compilati con il vecchio layout della struct; `rm -rf .build` + rebuild ha risolto. Regola: quando
  cambia il layout di un tipo pubblico del Kit, il package che lo usa va ricompilato da pulito
  (`swift package clean` in `Tools/catalog-builder`); `check_done.sh` lo fa sempre prima dei test del builder.

