---
name: cassa
description: |
  Quanta cassa c'è oggi nel gruppo Djungle e cosa sta per uscire. Trigger quando l'utente dice "/cassa", "quanti soldi abbiamo", "saldo dei conti", "com'è messa la cassa", "cosa esce questo mese", "quanto addebita la Visa", "ce la facciamo a fine mese". Legge da Cassia: saldi, carte Visa da addebitare, uscite ricorrenti. Sola lettura.
---

# /cassa

Risponde a una domanda: **quanta cassa c'è e quanta ne serve a breve**.

## Passi

1. `saldi` → un saldo per conto (un saldo per ogni conto del perimetro), con la data di lettura.
2. `carte` con `mese_addebito` = il prossimo giorno 10 → totale Visa per carta che uscirà dal conto collegato (ogni carta ha il suo conto di addebito nel registro).
3. Se l'utente chiede le prossime settimane: `riepilogo_mensile` sugli ultimi 3 mesi per ogni entità, e stima le uscite ricorrenti dalle categorie che si ripetono ogni mese (auto, banca, tasse e contributi, compensi, fornitori ricorrenti). Dichiara che è una stima dalla media.

## Come rispondi

- Prima riga: la cassa totale e quella per società, con la data del saldo.
- Poi cosa esce e quando (Visa il 10, ricorrenti), e il netto atteso a fine mese.
- Cifre in euro senza decimali, separatore delle migliaia col punto. I movimenti bancari sono di cassa, IVA inclusa: dillo se confronti con cifre di contratto, che sono nette.
- Se un saldo è più vecchio di 2 giorni, dillo.
- Mai consigli di investimento. Mai proporre bonifici: Cassia non muove soldi.
