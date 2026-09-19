# Gauntlet — lista prodotti SkinCare

**Bar**: sample Apple *Landmarks: Building an app with Liquid Glass* (iOS 26), compilato dallo zip
ufficiale e catturato sullo **stesso simulatore** (iPhone 17 Pro, iOS 26.2). Catture in `reference/`:
`landmarks-light.png`, `landmarks-dark.png`, `landmarks-light-axl.png`, `landmarks-dark-axl.png`.

**Pezzi** (giudicabili da soli): P1 riga (foto, titolo, marca, descrizione) · P2 struttura lista e chrome
(titolo, sezioni, spaziature, stati) · P3 modalità scura + Dynamic Type AX-L (con controllo geometrico) ·
P4 immagini (aspect, sfondo, placeholder) · P5 qualità dati (campione di 10 prodotti confrontati con OBF).

**Protocollo**: builder e critico sono sub-agent separati a contesto fresco. `blind.sh` copia la nostra
cattura e quella del bar come `A.png`/`B.png` con assegnazione casuale (la mappa va in `rounds/<pezzo>/
round-<n>/mapping.txt`, che il critico non legge). Il critico risponde solo con
`{"winner": "A"|"B", "biggest_gap": "..."}`. Uscita per pezzo: il critico sceglie la nostra alla cieca
(**VINTO**) oppure si raggiunge il **cap di 3 round** (**CAP**, con il gap residuo annotato).

**Log**: `LOG.md`, una riga finale per pezzo nel formato letto da `scripts/check_done.sh`:
`ESITO P<n>: VINTO|CAP — <nota>`.
