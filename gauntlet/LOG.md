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

Builder round 1 (P1+P2+P4, un solo agente): in corso.

ESITO P3: VINTO — round 1, alla cieca (dark + AX-L), nessuna modifica necessaria.
