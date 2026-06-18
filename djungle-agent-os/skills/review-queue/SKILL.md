---
name: review-queue
description: |
  Coda di review dei fact MEDIUM proposti dal writeback automatico (ADR-008b). Trigger quando l'utente dice "/review-queue", "coda review", "memoria in coda", "fact da rivedere", "cosa c'è in coda", "rivedi i fatti pendenti". v4.6.0+.
---

# /review-queue — Coda di review del writeback automatico (v4.6.0)

Da v4.6.0 le sessioni si chiudono e digeriscono da sole (writeback automatico).
Con la commit policy di default (`confidence_gated`), i fatti ad **alta**
confidence vengono applicati subito alla SOTA; quelli a **media** confidence
finiscono in una coda di review — qui — senza mai interrompere il lavoro.

## Comportamento

Chiama il tool MCP **`list_review_queue`** (default `status=pending_review`).
Risposta: `{ items[], groups }` — gli item raggruppati per iniziativa.

Mostra la coda raggruppata:

```
Memoria in coda — 5 fatti a media confidence da rivedere

[bp-djungle-holding-2026] BP Djungle Holding 2026
  [1] decisione: "first close target €30M spostato a Q1 2027"
  [2] metrica: runway = 14 mesi

[storytelling-ai] Storytelling AI
  [3] open loop +: "validare pricing tier consumer"

Per ognuno: accetta (applica alla SOTA) o rifiuta (scarta).
```

Per ogni item l'utente decide. Chiama **`resolve_review_item`**:

```
resolve_review_item({ item_id: "<uuid>", decision: "accept" })   // applica alla SOTA
resolve_review_item({ item_id: "<uuid>", decision: "reject" })   // scarta
```

- **accept** → il fact viene applicato alla SOTA dell'iniziativa (stesso path di commit dello Scribe).
- **reject** → l'item viene marcato rejected, niente modifiche.
- Idempotente: un item già risolto non viene ri-applicato.

Puoi offrire scorciatoie: "accetta tutti", "rifiuta tutti", o review uno per uno.
Per "accetta tutti" → cicla `resolve_review_item(accept)` su ogni `item_id` pending.

## Quando usarla

- Periodicamente, quando vuoi (la coda non scade né blocca).
- Il dashboard `agents.djungle.io/dashboard` mostra un widget "Memoria in coda"
  con il conteggio, come promemoria.
- Se la coda cresce troppo, il Librarian può segnalarlo come alert.

## Cosa NON fa

- ❌ Non chiude sessioni — quello è `/wb` o automatico (Trigger B / idle).
- ❌ Non tocca i fatti HIGH — quelli sono già in SOTA (auto-commit). Se uno è
  sbagliato, si corregge via `/sota-update` o si reverte dall'audit log.
- ❌ Non esiste se la commit policy del tenant è `auto_all` (tutto auto-commit,
  niente coda) o se non ci sono fatti medium pendenti.

## Note

- La commit policy è per-tenant: `confidence_gated` (default), `always_confirm`
  (tutto in coda, anche HIGH), `auto_all` (niente coda). Si configura lato admin.
- Tutto ciò che è auto-committato resta reversibile via audit log.
