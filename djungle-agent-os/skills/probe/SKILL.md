---
name: probe
description: |
  Show the unified context probe of an initiative — SOTA, recent sessions, pending handoffs, recent memory logs, references, and detected gaps. Trigger when the user says "/probe <slug>", "fammi vedere lo stato di X", "probe X", "guarda dentro X", "mi spieghi tutto di X". Read-only debugging/inspection — useful before invoking an agent on that initiative or to monitor health.
---

# Probe — full context inspection (v4.16.0)

> **Sessione sulle letture (ADR-014b / B9).** Passa `session_id` a ogni chiamata
> di lettura: senza, si legge dal tenant attivo — che può essere un altro
> workspace. Recupero e formato del marcatore: `skills/_shared/session-threading.md`.
> Controlla il `tenant_slug` in risposta: se non è quello della sessione, fermati.

Calls `probe_initiative_context` and renders the payload as structured markdown. Questa skill è il **probe pieno** (ADR-020: `probe_level: "full"` — quando passi dalla invoke, è questa la forma che si ottiene chiedendo `full`; la invoke di default usa il desk lean). Useful for:

- Pre-flight inspection before `invoke <agent> on <initiative>`
- Health monitoring (check carenze_detected for warnings)
- Cross-reference visualization (see what depends on what)
- Debug "where are we exactly?"

DB is canonical. Dal v4.16.0 non c'è più cache server-side: ogni probe è fresco.
I contenuti arrivano con le truncation E1 (`truncated: true` + `full_length`):
per il testo integrale di una sezione usa `get_sota_section`, per una memoria
`list_memory_logs`.

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
  memory_limit: 10             // esplicito: il default server è 3 (ADR-020 E1)
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

## Performance

- Probe: ~300-500ms (7 SELECT paralleli, funzione a dub1 dal v4.15).
- Niente cache dal v4.16.0 (ADR-020 §10.2): su lambda effimere il hit rate era
  ~0 e le invalidate instance-local mentivano. Ogni probe è fresco.

## Error handling

- Initiative not found → call list_initiatives, suggest valid slugs.
- Probe partial failure (one of the 5 SELECTs errors) → tool throws; show error and don't render incomplete.
- Anthropic API down (classifier sub-call from inside probe — but probe doesn't use classifier, so this isn't a concern in v3.2.0).

## What NOT to do

- ❌ Don't render "summary" fields without truncation — keep snippets short (200 char SOTA, 80 char memory).
- ❌ Don't mix probe with writes — read-only by design. If user wants to edit, suggest `/sota-update`.
- ❌ Don't auto-fix carenze without asking. Surface them, propose, wait.
