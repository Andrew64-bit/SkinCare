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
| P3 scuro (standard) + AX-L (chiaro) | A=ours B=bar | A | **VINTO** | (gap attribuito al bar: il testo dell'hero senza sfondo garantito si lava sulla neve ad AX-L; il pulsante flottante copre i titoli) |
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

(P3: vinto al round 1, vedi «Esiti finali».)

Verdetti round 2:

| Pezzo | Mappa | Sceglie | Esito | Gap più grande |
|---|---|---|---|---|
| P1 riga | A=bar B=ours | A | perso | descrizione = paragrafo nello stesso grigio della marca, righe 126–162 pt; chiesto `lineLimit(2)` + `.secondary` (entrambi vietati dall'audit) → tradotto in gerarchia: marca in colore pieno, descrizione in due righe brevi attenuate senza troncamenti |
| P2 struttura | A=ours B=bar | B | perso | pannello-scrim dietro occhiello e titolo («adesivo sulla foto») → testo direttamente su gradiente a tutta larghezza, in basso a sinistra, 16 pt |
| P4 immagini | A=ours B=bar | B | perso | tessera senza confine (foto bianca si dissolve nella card) → fondo `tertiarySystemFill` + filetto 0,5 pt `separator` |
| P5 dati | — | — | FAIL | 8/10 coerenti; 19/120 anteprime con token incollati/OCR, 18 crediti generici (`images: {}` nella ricerca), 4 sinonimi, 5 categorie implausibili, 7 marche non normalizzate |

Builder round 2 (P1+P2+P4, un agente, commit 57e65c8): hero senza pannello, gradiente `.clear → .black 0.75`
da y 0 (la base y 0,5 / 0,6 chiesta dal critico falliva il contrasto dell'occhiello: misurato 2,9:1, poi
5,2:1 dopo l'estensione); tessere `tertiarySystemFill` + `strokeBorder(separator, 0.5)`; riga: titolo e
marca `Color(.label)` (marca `.subheadline.medium`), descrizione in 2 righe footnote attenuate («Crema viso,
400 ml.» + «Ingredienti principali: …»), nessun lineLimit. Suite UI 8/8. Altezze riga invariate
(163/127/127 pt): senza troncamento non c'è margine.
Builder P5 round 2 → 3 (commit c7d80b5 + 8ddb15c): integrità dei primi 4 token, ≥ 2 ingredienti noti fra i
primi 4, sinonimi a più parti, marche e unità normalizzate, esclusioni per categoria (solventi unghie,
saponi), autore della foto dall'endpoint prodotto (19 recuperati: crediti generici 0/120). 61 test builder,
41 Kit, QUALITY=PASS.

## Round 3 — 2026-09-19 (commit 57e65c8) — ultimo round (cap)

Cattura nostra: `rounds/round-3/ours-light.png`. Mappe cieche: P1 A=bar B=ours · P2 A=ours B=bar ·
P4 A=ours B=bar. Critici P1/P2/P4 e P5 (round 3) lanciati a contesto fresco.

Verdetti round 3 (ultimo):

| Pezzo | Mappa | Sceglie | Esito | Nota |
|---|---|---|---|---|
| P1 riga | A=bar B=ours | A | **CAP** | gap residuo: la riga «Ingredienti principali» va a capo su 2–3 righe e le altezze variano (3–5 righe); la soluzione proposta (`lineLimit(1)`) è incompatibile con l'audit di accessibilità (testo tagliato) — scelta consapevole: leggibilità completa prima del ritmo |
| P2 struttura | A=ours B=bar | A | **VINTO** | titolo grande reale, hero allineato ai margini, lista raggruppata pulita; al bar: nessun titolo, chevron «indietro» su schermata radice, pulsante flottante che copre un'etichetta |
| P4 immagini | A=ours B=bar | B | **CAP** | gap residuo: miniature 72 pt quadrate in alto in righe 2–3 volte più alte; prossimo passo suggerito: riquadro verticale 104×130 (4:5) centrato sul blocco di testo, filetto invariato |
| P5 dati | — | — | **CAP** | 8/10 coerenti; 16/120 anteprime con rumore OCR o token incollati (13 %), credito foto alla lingua sbagliata in ~10 % dei prodotti multilingua |

Correzioni **post-cap** (fuori dal loop, senza nuovo round, commit 0c78607): credito foto dalla chiave
`front_<lingua>` dell'URL dell'immagine (Nivea Creme: da «smoothie-app» a «scailyna», autore della foto
davvero mostrata — rilevante per CC BY-SA), primi 4 ingredienti solo in alfabeto latino, nessun «..» finale;
66 test builder, 41 Kit, QUALITY=PASS, crediti generici 0/120. Gap residuo P5: rumore OCR nelle anteprime
(prossimo passo: validare tutti i primi 4 token contro un dizionario INCI completo, es. CosIng).

## Esiti finali

ESITO P1: CAP — altezze riga variabili per l'anteprima ingredienti a capo; lineLimit vietato dall'audit.
ESITO P2: VINTO — round 3, alla cieca (struttura: titolo, hero a margini, sezioni).
ESITO P3: VINTO — round 1, alla cieca (modalità scura a taglia standard + Dynamic Type AX-L in chiaro; la coppia scura AX-L esiste ma non è stata giudicata).
ESITO P4: CAP — miniature quadrate 72 pt; prossimo passo riquadro 4:5 centrato.
ESITO P5: CAP — 16/120 anteprime con rumore OCR; crediti foto corretti post-cap.

## v0.2 — P6 ricerca (cap 2 round) — 2026-09-19

Bar del piano: la ricerca del sample Landmarks. Sul simulatore il suo `.searchable` vive nella colonna
laterale dello split view e su iPhone non mostra risultati → non confrontabile. Catture via XCUITest
(`testCaptureSearchScreens`, `TEST_RUNNER_SKINCARE_BAR_CAPTURE=1`), perché il pannello del simulatore di
Claude richiede `sudo xcode-select`. Nostra: rete reale.

**Round 1 — annullato.** Bar = ricerca dell'app Impostazioni con «Wi»: nel simulatore Impostazioni non ha
indice di ricerca e la cattura era «No Results for “Wi”». Il critico aveva scelto A (nostra) proprio perché
«B mostra solo uno stato vuoto»: confronto non valido (nostri risultati contro uno stato vuoto altrui, nostro
stato vuoto mai giudicato). Rilevato dal verificatore indipendente; il verdetto non conta.
Osservazione utile dalla nostra cattura: tre «Nivea Creme» quasi identiche (barcode diversi per
formato/mercato) → deduplica per marca+nome+formato aggiunta al builder (test), attiva dal catalogo rigenerato.

**Round 2.** Bar = ricerca dell'app **Contatti** di sistema (stesso simulatore, contatti di esempio
precaricati): coppia risultati («ha» → Anna Haro, Hank M. Zakroff · nostra «nivea») e coppia stati vuoti
(«zzzzqqqq» in entrambe). `rounds/P6/round-2/` e `rounds/P6-empty/round-2/`, mappe cieche A=ours B=bar in
entrambe. Prompt del critico senza premesse sul contenuto delle catture. Verdetto: **B (bar)** → perso.
Motivo: campo agganciato sopra la tastiera, righe di una sola riga sotto un'intestazione «matches», stato
vuoto leggero e centrato; da noi campo in alto, righe di quattro righe senza evidenza della corrispondenza,
card «nessun risultato» pesante più la riga di licenza (che però resta: obbligo ODbL/CC BY-SA in ogni stato).
Gap residuo (prossimo passo): durante la ricerca usare una riga compatta — titolo con la parte
corrispondente in grassetto (`AttributedString`), una riga «marca · formato», senza ingredienti — due righe
per risultato invece di quattro, senza troncamenti (regole audit).

ESITO P6: CAP — round 1 annullato (bar in stato vuoto), round 2 perso contro la ricerca di Contatti; gap residuo: riga compatta con corrispondenza evidenziata.

## v0.3 — P7 immagini ritagliate + badge (cap 2 round) — 2026-09-20

Bar: Landmarks (catture in `reference/`, chiaro e scuro). Nostra: rete reale con i ritagli serviti da Pages
(`rounds/P7/round-1/ours-{light,dark}.png`); coppie cieche `P7` e `P7-dark`, mappa A=bar B=ours in entrambe.
Nota di processo: la prima cattura mostrava foto originali «fit» su bianco scambiate per ritagli; il test UI
(`value == loaded:cutout`) ha smascherato una sostituzione di testo non applicata in `ProductImageView`
(`.task(id: url200)` invariato). Regola: ogni sostituzione di testo negli script va asserita.

Round 1 — critico: **A (bar)** → perso. Gap: nella card in evidenza il ritaglio (~46×100 pt) galleggia in
alto a destra lasciando ~70 % della card vuota; le tessere mescolano ritaglio su grigio e foto piena; il
badge pesa più della marca. Fix chiesto: palco a tutta larghezza (`RoundedRectangle(16)` in
`tertiarySystemFill`, 180 pt), ritaglio `scaledToFit` al 75 % dell'altezza centrato, marca/badge/titolo sotto.

