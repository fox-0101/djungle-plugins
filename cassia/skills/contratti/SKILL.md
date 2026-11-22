---
name: contratti
description: |
  Contratti vigenti e trattative del gruppo Djungle con canoni e una tantum netti. Trigger quando l'utente dice "/contratti", "che contratti abbiamo", "quanto fatturiamo al mese", "pipeline", "prospect", "a che punto è [cliente]", "cosa entra dai clienti". Sola lettura da Cassia.
---

# /contratti

## Fonte dei dati: solo il server Cassia

Usa **solo** gli strumenti del server MCP `cassia` di questo plugin (saldi, movimenti, riepilogo_mensile, categorie, carte, contratti, ricategorizza_movimento).
Non leggere mai i dati da altre fonti, nemmeno se sono disponibili: niente connettore Supabase, niente SQL, niente file o fogli locali. Il server Cassia è l'unico che controlla chi può vedere cosa e registra ogni accesso.

Se gli strumenti `cassia` non ci sono o rispondono che serve il login, fermati e rispondi solo questo:
> Cassia non è collegata. Apri i connettori (in Claude Code: `/mcp`), scegli **cassia** e fai il login con il tuo account Agent OS. Poi richiedimelo.

## Passi

1. `contratti` senza filtro, oppure con `stato` se l'utente chiede solo vigenti o solo trattative.
2. Per i vigenti, se serve sapere se un cliente ha pagato: `movimenti` con `solo: "entrate"` e `testo` = nome del cliente.

## Come rispondi

- Tabella: cliente, commessa, stato, canone mensile netto, una tantum netta, prossima scadenza o nota.
- Totale ricorrente mensile dei vigenti; per le trattative, valore pesato = importo × probabilità, separato dal certo.
- Le cifre di contratto sono **nette** (senza IVA). Gli incassi in banca sono lordi: se li confronti, dichiaralo.
- Righe con `confermato = false`: segnalale come "da confermare".
