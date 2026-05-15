---
name: librarian-now
description: |
  Avvia un run on-demand del Librarian (consolidation cycle della knowledge base del tenant). Trigger quando l'utente dice "/librarian-now", "avvia il librarian", "lancia il librarian ora", "fai un run del librarian", "consolidation ora", "analizza la knowledge base adesso". v4.2.0+.
---

# /librarian-now — Run on-demand del Librarian (v4.2.0)

Avvia immediatamente un consolidation cycle del Librarian, senza aspettare lo schedule settimanale.

## Comportamento

Chiama il tool MCP `librarian_now`.

Conferma all'utente:

```
✓ Librarian run avviato (run_id abc12345…).
Il consolidation cycle a 5 fasi gira async — 5-10 minuti.
Per il risultato: /briefing (quando completato) o il dashboard
agents.djungle.io/dashboard/librarian
```

## Edge cases

- **Librarian non abilitato** → il tool ritorna un errore esplicito. Istruisci
  l'utente ad attivarlo da `agents.djungle.io/dashboard/settings` → sezione Librarian.
- **Tool non disponibile** → il connector MCP djungle-agent-os va riconnesso
  in Cowork (Customize → Connettori) per aggiornare la lista tool.

## Cosa NON fa

- ❌ Non aspetta il completamento — il run è async. Non restare in attesa in chat.
- ❌ Non abilita il Librarian — quello è in Settings portal.

Per stato e alert: skill `/librarian`. Per il briefing: skill `/briefing`.
