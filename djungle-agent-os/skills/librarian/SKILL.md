---
name: librarian
description: |
  Gestione del Librarian del tenant — l'agente di background che analizza la coerenza della knowledge base e produce briefing periodici. Trigger quando l'utente dice "/librarian", "/librarian-now", "/librarian-status", "/briefing", "fammi vedere il briefing", "stato del librarian", "avvia il librarian", "lancia consolidation". v4.2.0+.
---

# /librarian — Librarian del tenant (v4.2.0)

Il Librarian è un Anthropic Managed Agent che ogni settimana (+ on-demand) esegue un consolidation cycle a 5 fasi (orient → prune → merge → reorganize → surface) sulla knowledge base del tenant: SOTA, memory logs, sessioni, handoff. Produce un briefing leggibile + alert prioritari su drift, contraddizioni, duplicazioni.

## Sub-commands

### `/librarian` o `/librarian-status`

Mostra lo stato del Librarian. Usa il tool MCP `list_librarian_runs` (limit 1) + `list_librarian_alerts` (acknowledged=no).

Output:

```
Librarian — tenant djungle

Ultimo run:   2026-05-12 06:04 · completed · 6 min · 18k/7k token
Prossimo run: 2026-05-19 06:00 (settimanale, lunedì)

Alert pendenti: 3 critical · 5 warning · 12 info

Per il briefing completo: /briefing
Per un run ora:           /librarian-now
Dashboard:                agents.djungle.io/dashboard/librarian
```

Se il Librarian non è abilitato:

```
Il Librarian non è abilitato per questo tenant.
Attivalo da agents.djungle.io/dashboard/settings → sezione Librarian.
```

### `/librarian-now`

Avvia un run on-demand. Usa il tool MCP `librarian_now`.

Conferma:

```
✓ Librarian run avviato (run_id abc12345…).
Il consolidation cycle gira async — 5-10 minuti.
Riceverai il briefing in agents.djungle.io/dashboard/librarian al completamento.
```

Se non abilitato → istruisci ad attivarlo da Settings (il tool ritorna l'errore esplicito).

### `/briefing`

Ritorna il briefing markdown dell'ultimo run completato. Usa il tool MCP `get_briefing` (senza run_id = ultimo run).

Renderizza il markdown del briefing direttamente in chat. Se non c'è alcun run completato, spiega che il primo run deve ancora girare (`/librarian-now` per avviarlo).

### Mostrare gli alert in dettaglio

Se l'utente chiede "quali sono gli alert" / "fammi vedere i problemi": usa `list_librarian_alerts` e mostra gli alert raggruppati per severity. Per ogni alert: tipo, iniziativa coinvolta, titolo, azione suggerita.

Per marcare un alert come gestito: `acknowledge_alert(alert_id, resolution_type)` dove resolution_type ∈ `actioned` (gestito) | `dismissed` (ignora) | `deferred` (rimanda — non chiude l'alert). Chiedi sempre conferma prima di acknowledge multipli.

## Important rules

- **Read + trigger, non auto-fix.** Il Librarian segnala; non corregge automaticamente contraddizioni o duplicati. Le risoluzioni le decide l'utente (o un agente conversazionale dopo approvazione).
- **Run async.** `/librarian-now` non blocca: il risultato arriva via webhook, 5-10 min. Non aspettare in chat — dì all'utente di controllare il dashboard.
- **Tenant-scoped.** Tutti i tool Librarian operano sul tenant corrente via RLS. Un tenant non vede mai runs/alert di altri.
- **Abilitazione.** Enable/disable e schedule si gestiscono da `/dashboard/settings` (portal) — non da questa skill. La skill è status + trigger + briefing.

## Cosa NON fa

- ❌ Non abilita/disabilita il Librarian (è in Settings portal)
- ❌ Non corregge i problemi rilevati — solo segnalazione
- ❌ Non gira sincrono — il run è async via Managed Agent

## Note tecniche

- Backend: Anthropic Managed Agent (Beta). 1 Agent + 1 Environment condivisi, Memory Store per-tenant, isolamento dati via API key MCP dedicata.
- Il consolidation cycle legge i dati del tenant via MCP Connector verso lo stesso server (`get_sota`, `list_memory_logs`, `list_sessions`, `list_pending_handoffs`, `list_initiatives`).
- Cron weekly default lunedì 06:00 (timezone tenant). On-demand sempre disponibile.
