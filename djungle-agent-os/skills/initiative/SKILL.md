---
name: initiative
description: |
  Manage initiatives (create, list, show, archive, link). Trigger when the user says "/initiative create ...", "/initiative list", "/initiative show <slug>", "/initiative archive <slug>", "/initiative link X Y depends_on", "crea iniziativa", "archivia iniziativa", "collega <X> a <Y>". Initiatives are the persistent units of work — anything with an ongoing state worth tracking.
---

# Initiative — registry CRUD (v3.2.0)

Sub-commands:

- `/initiative create <name> [--domain=<slug>] [--type=<type>] [--stage=<stage>]`
- `/initiative list [--domain=<slug>] [--stage=<stage>] [--type=<type>]`
- `/initiative show <slug>`
- `/initiative archive <slug> [--reason=<manual|classifier_false_positive|other>]`
- `/initiative link <source-slug> <target-slug> --relation=<type> [--notes="..."]`

DB is canonical. Use this skill explicitly when you want to manage the registry without going through invoke_agent's resolver.

## Types & stages reference

**Types:** `business`, `thesis`, `experiment`, `sideproject`, `deliverable`, `campaign`.
**Stages:** `idea`, `exploring`, `building`, `operating`, `paused`, `killed`, `delivered`, `archived`.
**Relation types:** `depends_on`, `references`, `output_of`, `parent_of`, `sibling`, `spawns`.

If user is unsure about type/stage, suggest based on description (e.g. "una cosa che produce un output con scadenza" → `deliverable`).

## Create

```
/initiative create "Storytelling AI" --domain=djungle-holding --type=business
```

Flow:

1. Slug derivation: lowercase + dash from name. Show to user before submit ("slug sarà `storytelling-ai`, ok?").
2. If no domain supplied, ask which domain or default to `uncategorized` (auto-create `uncategorized` domain only on first use).
3. Call `create_initiative({slug, name, type, domain_slug, stage?, description?})`.
4. Side-effect: server seeds 6 empty canonical SOTA sections automatically.
5. Confirm: `Iniziativa 'storytelling-ai' creata. 6 sezioni SOTA seedate vuote. Apri /sota storytelling-ai per popolarle.`

## List

```
/initiative list                       → all active
/initiative list --domain=djungle-holding
/initiative list --stage=building
/initiative list --type=deliverable
```

Call `list_initiatives` with the filters. Render markdown table:

```
| Slug | Name | Domain | Type | Stage | Last touched |
|------|------|--------|------|-------|--------------|
| ... | ... | ... | ... | ... | 2 giorni fa |
```

## Show

```
/initiative show storytelling-ai
```

Call `get_initiative({slug})` + `get_sota({initiative_slug})` for `current_state` only. Show as a 1-page card:

```
# Storytelling AI
type: business · stage: building · health: green · priority: 3
domain: djungle-holding
last_touched: 2026-05-04 18:23

## Current state (snippet)
[first 200 char of current_state, or "_(SOTA non valorizzata)_"]
```

## Archive

```
/initiative archive svuotamente --reason=manual
```

Call `archive_initiative({slug, reason})`. Default reason: `manual`. Confirm to user.

`classifier_false_positive` use case: the resolver auto-created an initiative via the classifier but the user later said "non era un'iniziativa". Set reason for analytics tracking false-positive rate.

## Link (references)

```
/initiative link investor-update-may-2026 bp-djungle-holding-2026 --relation=depends_on
```

Call `link_initiatives({source_slug, target_slug, relation_type, notes?})`. Idempotent — if already linked, returns the existing reference id with `created: false`.

For `unlink`, suggest: `/initiative unlink <source> <target> --relation=<type>`.

## Error handling

- Slug already exists on create → suggest a variant (`storytelling-ai-2026`) or ask if user wants to update the existing.
- Slug not found on update/archive/link → call list_initiatives.
- Domain slug not found → suggest creating it first via UI on Notion (or future `/domain create` skill).
- Self-link (source == target) → block with clear error.

## What NOT to do

- ❌ Don't bypass `create_initiative` to insert directly — seeding SOTA is part of the contract.
- ❌ Don't link 2 initiatives without confirming the relation_type makes sense (e.g. `output_of` between 2 unrelated initiatives is wrong).
- ❌ Don't archive without showing the user current_state first if it's non-empty (could lose context).
