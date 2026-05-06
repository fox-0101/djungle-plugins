---
name: sota
description: |
  Read-only access to the SOTA (State of the Art) of an initiative or domain. Trigger when the user says "/sota", "/sota <slug>", "/sota <slug> <section>", "mostra la sota di X", "qual è lo stato di X", "dimmi dove siamo con X", "mostra le iniziative", "lista iniziative". Returns formatted markdown — never modifies anything.
---

# SOTA — read-only state inspection (v3.2.0)

Inspect an initiative's State of the Art without any side-effects. Three modes:

1. `/sota` — list all active initiatives of the tenant grouped by domain
2. `/sota <slug>` — render the full SOTA of one initiative
3. `/sota <slug> <section>` — render only one section

DB is canonical. Use `update_sota_section` (different skill) to modify.

## When to trigger

- `/sota` — root list
- `/sota storytelling-ai` — full SOTA for that initiative
- `/sota storytelling-ai current_state` — only that section
- "qual è lo stato di X" / "dove siamo con X" / "mostra la sota di X"
- "che iniziative ho?" / "lista iniziative"

## Mode 1 — list initiatives

If user said `/sota` (no args) or "lista iniziative":

```
list_initiatives({ archived: false })
```

Render markdown grouped by `parent_domain_id` (resolve domain via `list_domains`):

```
# Iniziative attive — Djungle

## Djungle Holding
- **bp-djungle-holding-2026** (deliverable, building) — Aggiornamento BP 2026
- **storytelling-ai** (business, building) — Prodotto storytelling famiglie
- ...

## Agent OS
- **agent-os-platform** (business, building) — Il sistema stesso
- ...
```

Show last_touched in italic small text if available (`(last touched: 3 giorni fa)`).

## Mode 2 — full SOTA of an initiative

User: `/sota storytelling-ai`

```
get_sota({ initiative_slug: "storytelling-ai" })
```

Render markdown:

```
# SOTA — Storytelling AI
type: business · stage: building · domain: djungle-holding

## What it is
[content of what_it_is section, or "_(non valorizzata)_" if null]

## Current state
...

## Last 3 moves
...

## Open loops
...

## Next action
...

## Decisions log
...
```

Use 6 canonical headings in this order. Show optional sections (metrics/risks/people/references) only if present.

If a section's content_md is null/empty, show "_(non valorizzata)_" in italic — never invent content.

## Mode 3 — single section

User: `/sota storytelling-ai current_state`

```
get_sota_section({ initiative_slug: "storytelling-ai", section_name: "current_state" })
```

Render just that section as a single markdown block.

For `section_name='custom'`, the user must also supply a custom_label: `/sota storytelling-ai custom marketing-plan`.

## Error handling

- Initiative not found → call `list_initiatives` and suggest valid slugs.
- Section name invalid → list the canonical names: `what_it_is, current_state, last_3_moves, open_loops, next_action, decisions_log` + optionals `metrics, risks, people, references, custom`.
- 401 → OAuth session expired. Disconnect+reconnect connector.

## What NOT to do

- ❌ Don't write or modify SOTA from this skill — read-only by design.
- ❌ Don't fabricate content for empty sections — show "_(non valorizzata)_".
- ❌ Don't bypass `list_initiatives` for the listing — always use the tool.
