---
name: probe
description: |
  Show the unified context probe of an initiative — SOTA, recent sessions, pending handoffs, recent memory logs, references, and detected gaps. Trigger when the user says "/probe <slug>", "fammi vedere lo stato di X", "probe X", "guarda dentro X", "mi spieghi tutto di X". Read-only debugging/inspection — useful before invoking an agent on that initiative or to monitor health.
---

# Probe — full context inspection (v3.2.0)

Calls `probe_initiative_context` and renders the payload as structured markdown. Useful for:

- Pre-flight inspection before `invoke <agent> on <initiative>`
- Health monitoring (check carenze_detected for warnings)
- Cross-reference visualization (see what depends on what)
- Debug "where are we exactly?"

DB is canonical. The probe is cached server-side 5 min, invalidated automatically on writes (sessions, handoffs, memory_logs, sota_sections).

## When to trigger

- `/probe <slug>`
- "fammi vedere lo stato di X"
- "mi spieghi tutto di X"
- "guarda dentro X"
- "probe X"

## Step-by-step

### 1. Call probe_initiative_context

```
probe_initiative_context({
  initiative_slug: "<slug>",
  depth_references: 1,        // default
  sessions_limit: 5,           // default
  include_memory: true,        // default
  memory_limit: 10
})
```

### 2. Render markdown report

```
# Probe — <name> (<slug>)
type: <type> · stage: <stage> · health: <health> · domain: <domain.name>
last_touched: <ISO formatted "2 giorni fa" via humanize>
cache: <"hit" | "fresh">

## SOTA
[render canonical sections in order, mark optional ones if present]
- **what_it_is**: [first 200 char or "_(non valorizzata)_"]
- **current_state**: ...
- **last_3_moves**: ...
- **open_loops**: ...
- **next_action**: ...
- **decisions_log**: ...

## Recent sessions (N)
- SES-N · agent · started_at · "summary 60 char..." · [open|closed]
- ...

## Pending handoffs (N)
- HND-N · from → to · priority · topic · created_at
- ...

## Recent memory logs (N)
- MEM-N · agent · type · "first 80 char..." · created_at
- ...

## References (N outgoing, M incoming)
**Outgoing:**
- depends_on → <related-initiative-slug>: "<sota_summary first 200 char>"

**Incoming:**
- <relation> ← <other-slug>: "<sota_summary>"

## Carenze detected (N)
[only show if non-empty]
⚠️ **warning**:
- stale_initiative: Iniziativa attiva non toccata da 35 giorni
- open_loop_old: Loop aperto da 18 giorni (data 2026-04-18)

ℹ️ **info**:
- missing_sota_section: Sezione next_action non valorizzata
- missing_kpi: KPI non definiti per iniziativa di tipo business
```

### 3. Suggested next actions

After rendering, optionally suggest 1-2 next moves to the user based on carenze:

- If `missing_sota_section.next_action` → "Vuoi popolare la next_action ora? Posso aiutarti."
- If `stale_initiative` → "Vuoi aggiornare current_state o archiviare?"
- If `open_loop_old` → "C'è un loop vecchio. Lo gestiamo?"

Don't be pushy — suggerimenti, non comandi.

## Performance & caching

- First probe of an initiative: cold, ~500ms-1s (5 parallel SELECTs).
- Subsequent within 5 min: warm cache, <50ms.
- Cache is invalidated automatically when:
  - SOTA section is updated/deleted
  - A new session/handoff/memory_log links to that initiative
  - References to/from change
- The user doesn't need to manually invalidate — just call probe again.

## Error handling

- Initiative not found → call list_initiatives, suggest valid slugs.
- Probe partial failure (one of the 5 SELECTs errors) → tool throws; show error and don't render incomplete.
- Anthropic API down (classifier sub-call from inside probe — but probe doesn't use classifier, so this isn't a concern in v3.2.0).

## What NOT to do

- ❌ Don't render "summary" fields without truncation — keep snippets short (200 char SOTA, 80 char memory).
- ❌ Don't mix probe with writes — read-only by design. If user wants to edit, suggest `/sota-update`.
- ❌ Don't auto-fix carenze without asking. Surface them, propose, wait.
