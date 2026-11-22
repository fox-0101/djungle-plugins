---
name: contratti
description: |
  Contratti vigenti e trattative del gruppo Djungle con canoni e una tantum netti. Trigger quando l'utente dice "/contratti", "che contratti abbiamo", "quanto fatturiamo al mese", "pipeline", "prospect", "a che punto è [cliente]", "cosa entra dai clienti". Sola lettura da Cassia.
---

# /contratti

## Passi

1. `contratti` senza filtro, oppure con `stato` se l'utente chiede solo vigenti o solo trattative.
2. Per i vigenti, se serve sapere se un cliente ha pagato: `movimenti` con `solo: "entrate"` e `testo` = nome del cliente.

## Come rispondi

- Tabella: cliente, commessa, stato, canone mensile netto, una tantum netta, prossima scadenza o nota.
- Totale ricorrente mensile dei vigenti; per le trattative, valore pesato = importo × probabilità, separato dal certo.
- Le cifre di contratto sono **nette** (senza IVA). Gli incassi in banca sono lordi: se li confronti, dichiaralo.
- Righe con `confermato = false`: segnalale come "da confermare".
