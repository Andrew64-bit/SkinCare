# Gauntlet — registro dei round

Bar: Apple Landmarks (iOS 26), stesso simulatore (iPhone 17 Pro, iOS 26.2). Catture del bar in `reference/`.
Critici e builder: sub-agent separati a contesto fresco. Confronto alla cieca (`blind.sh`, mappa in
`rounds/<pezzo>/round-<n>/mapping.txt`, mai mostrata al critico). Cap: 3 round per pezzo.

## Round 1 — 2026-09-19 (commit 2002152 + PROGRESS)

Catture nostre: `rounds/round-1/ours-{light,dark,light-axl,dark-axl}.png` (rete reale, foto OBF).

| Pezzo | Mappa cieca | Critico sceglie | Esito | Gap più grande (parole del critico, sintetizzate) |
|---|---|---|---|---|
| P1 riga | A=bar B=ours | A | **perso** | Miniature aspect-fit, non ritagliate, larghezza variabile (46–51 pt), sfondi fotografici che invadono la riga → un unico riquadro fisso 72×72, `scaledToFill`, `RoundedRectangle(12, continuous)`, sfondo `secondarySystemFill`, allineato al titolo |
| P2 struttura | A=bar B=ours | A | **perso** | La prima schermata è titolo grande + card di attribuzione «da piè di pagina» e poi una sezione indistinta → spostare l'attribuzione (scheda «i» / fine lista) e aprire con una card «in evidenza» a tutta larghezza (~200 pt, foto con gradiente, titolo in overlay) sotto il titolo |
| P3 scuro + AX-L | A=ours B=bar | A | **VINTO** | (gap attribuito al bar: il testo dell'hero senza sfondo garantito si lava sulla neve ad AX-L; il pulsante flottante copre i titoli) |
| P4 immagini | A=ours B=bar | B | **perso** | Stesso gap di P1: riquadro 64×64 fisso, `scaledToFill` + clip, `secondarySystemFill`, raggio 12, 12 pt dal testo |
| P5 dati | — | — | in corso | critico dati su 10 prodotti campionati + scansione sistematica |

Valori prima del round 2 (per ricostruire): `ProductImageView` frame 72×72, `.scaledToFit().padding(6)`,
sfondo `secondarySystemGroupedBackground`, raggio 14; riga con attribuzione come **prima** Section
(Button → scheda), intestazioni `title3.semibold` in `Color(.label)`; nessuna card in evidenza.

Builder round 1 (P1+P2+P4, un solo agente) — cambi applicati (commit 27cff8d):
- `ProductImageView`: 72×72 fisso, `.scaledToFill()` + clip `RoundedRectangle(12, continuous)`, sfondo
  `secondarySystemFill` (prima: `scaledToFit().padding(6)`, sfondo bianco su bianco, raggio 14).
- `FeaturedProductCard` (nuova): primo prodotto a tutta larghezza sotto il titolo, `minHeight 200`,
  `listRowInsets` zero, gradiente in basso, occhiello marca + nome in bianco su scrim `black 45 %` (raggio 14)
  con ombra; stesso menu contestuale delle righe.
- Attribuzione: da prima Section a **ultima** Section (riga Button → scheda; identifier/value invariati);
  la data ISO del catalogo esposta anche come `accessibilityValue` del pulsante «i».
- Test UI: le due prove sull'attribuzione scorrono fino in fondo (max 40 gesti veloci; raggiunta in 22).
- Suite UI: 8/8 verdi (2 diagnostici saltati). Audit di accessibilità verde.
Nota di processo: il builder è rimasto attivo dopo la sua «fine» e ha lanciato un secondo `xcodebuild`
mentre l'orchestratore ne eseguiva uno → entrambi crollati; fermato con TaskStop, lezione in CLAUDE.md.

P5 round 1 (critico dati, 10 prodotti + scansione): **FAIL** — 6/10 coerenti; 20/120 anteprime non-INCI
(indirizzo, lista di un formaggio, codici, OCR), 10 sinonimi «Aqua/Water», 8 quantità sporche, 4 categorie
implausibili. Gap: nessun controllo di plausibilità sugli ingredienti.
Builder P5 round 1 → 2 (`Tools/catalog-builder`, TDD, 52 test): plausibilità (≥ 5 token, un ingrediente
cosmetico noto fra i primi 4 da `INCIVocabulary`, `ingredients_n ≥ 5` se presente — NON il rapporto
sconosciuti/totali proposto dal critico: in OBF Nivea Creme ha 20 «sconosciuti» su 22 e la regola avrebbe
scartato 53 prodotti su 78), codici iniziali, «. »+maiuscola come separatore, sinonimi compatti «Aqua/Water»,
token con `[ ] ? °` scartati, quantità normalizzate («473ml - …» → «473 ml», altrimenti omessa: 14/120),
nomi senza lettere latine o uguali al barcode scartati. Catalogo rigenerato: 120 prodotti, QUALITY=PASS.

## Round 2 — 2026-09-19 (commit 27cff8d)

Catture nostre: `rounds/round-2/ours-{light,dark,light-axl}.png`. Mappe cieche: P1 A=bar B=ours ·
P2 A=ours B=bar · P4 A=ours B=bar. Critici P1/P2/P4 e P5 (round 2) lanciati a contesto fresco.

ESITO P3: VINTO — round 1, alla cieca (dark + AX-L), nessuna modifica necessaria.
