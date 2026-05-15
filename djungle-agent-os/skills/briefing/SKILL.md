---
name: briefing
description: |
  Mostra il briefing settimanale dell'ultimo run completato del Librarian. Trigger quando l'utente dice "/briefing", "fammi vedere il briefing", "briefing settimanale", "report del librarian", "cosa ha trovato il librarian". v4.2.0+.
---

# /briefing — Briefing del Librarian (v4.2.0)

Mostra il briefing markdown dell'ultimo run completato del Librarian.

## Comportamento

Chiama il tool MCP `get_briefing` (senza argomenti = ultimo run completato).
Il tool fa anche un reconcile inline: se un run on-demand è appena finito,
lo cattura ora.

Renderizza il markdown del briefing direttamente in chat. Il briefing ha
tipicamente le sezioni: Sintesi · Drift · Contraddizioni · Opportunità ·
Azioni consigliate.

Dopo il briefing, suggerisci: per gli alert in dettaglio usa `/librarian`.

## Edge cases

- **Nessun run completato** → spiega che il primo run deve ancora girare o
  completarsi. Per avviarne uno: `/librarian-now`. Un run dura ~5-10 min.
- **Librarian non abilitato** → attivalo da `agents.djungle.io/dashboard/settings`.
- **Tool non disponibile** → riconnetti il connector djungle-agent-os in Cowork.

## Cosa NON fa

- ❌ Non avvia run (usa `/librarian-now`)
- ❌ Non gestisce alert (usa `/librarian`)
