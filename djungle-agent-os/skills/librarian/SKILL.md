---
name: librarian
description: |
  Stato del Librarian del tenant — l'agente di background che analizza la coerenza della knowledge base e produce briefing periodici. Trigger quando l'utente dice "/librarian", "stato del librarian", "come va il librarian", "alert del librarian", "cosa ha segnalato il librarian". Per avviare un run usa /librarian-now; per il briefing usa /briefing. v4.2.0+.
---

# /librarian — Stato del Librarian (v4.2.0)

Il Librarian è un Anthropic Managed Agent che ogni settimana (+ on-demand) esegue un consolidation cycle a 5 fasi (orient → prune → merge → reorganize → surface) sulla knowledge base del tenant: SOTA, memory logs, sessioni, handoff. Produce un briefing leggibile + alert prioritari su drift, contraddizioni, duplicazioni.

Skill correlate: **/librarian-now** (avvia un run) · **/briefing** (ultimo briefing).

## Comportamento

Mostra lo stato del Librarian. Usa il tool MCP **`librarian_status`** — ritorna in un colpo solo: `enabled` (abilitato sì/no), schedule, ultimo/prossimo run, conteggio alert pendenti per severity.

⚠️ Per sapere se il Librarian è abilitato usa SEMPRE `librarian_status.enabled`. NON dedurlo da `list_librarian_runs` vuoto: una lista run vuota significa solo "nessun run ancora eseguito", NON "non abilitato". Un tenant appena abilitato ha 0 run finché non parte il primo (schedulato o `/librarian-now`).

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
