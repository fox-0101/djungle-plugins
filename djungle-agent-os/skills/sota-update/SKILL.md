---
name: sota-update
description: |
  Update one section of an initiative's SOTA (State of the Art). Trigger when the user says "/sota-update <slug> <section> <content>", "aggiorna la sota di X", "aggiorna current_state di X", "scrivi su X next_action ...", or any explicit request to modify a SOTA section.
---

# SOTA Update — write a single section (v3.2.0)

Persist a SOTA section UPSERT on `(tenant_id, parent_type, parent_id, section_name, custom_section_label)`. Side effect: invalidates the probe cache for that initiative so the next `/probe` or `invoke_agent` sees the fresh content.

## When to trigger

- `/sota-update <slug> <section> "<content>"`
- "aggiorna la current_state di Storytelling AI con: ..."
- "scrivi nelle next_action di BP: ..."
- The active agent says "vorrei aggiornare la SOTA con X" — propose to the user, then call.

## Step-by-step

### 1. Identify target

- Initiative slug (or domain slug for domain-level SOTA, rare)
- Section name: must be one of the canonical 6 (`what_it_is`, `current_state`, `last_3_moves`, `open_loops`, `next_action`, `decisions_log`) or optional (`metrics`, `risks`, `people`, `references`, `custom`).
- For `custom`: also a `custom_label` (max 60 char, lowercase-dash style suggested).

### 2. Compose content

Markdown libero. Suggerimenti:

- **`current_state`** — 3-8 righe: situazione corrente, milestone più recente, blocchi.
- **`last_3_moves`** — 3 bullet con timestamp ISO `(2026-05-06)` se conosciuto.
- **`open_loops`** — bullet con `[YYYY-MM-DD]` di apertura e descrizione 1-line.
- **`next_action`** — 1 frase imperativa concreta. NO "esplorare opzioni" — sempre azione.
- **`decisions_log`** — riga per ogni decisione: `[YYYY-MM-DD] <decisione> — <motivazione 1-line>`.

If user gave a high-level instruction ("aggiorna current_state di Bridge"), draft the content yourself based on conversation context, show to user, ask for confirmation before calling the tool.

### 3. Call `update_sota_section`

```
update_sota_section({
  initiative_slug: "storytelling-ai",
  section_name: "current_state",
  content_md: "MVP in test con 3 famiglie...",
  actor_agent: "AGT-2"  // optional, only if an agent is asking on behalf of the user
})
```

If the active agent (from `invoke_agent`) is the one suggesting the update, pass `actor_agent: "<agent_id>"` so audit_log records `agent:AGT-N` instead of `user:<uuid>`.

### 4. Confirm to user

```
Aggiornata sota_sections:
  initiative: storytelling-ai
  section: current_state
  by: agent:AGT-2 · 2026-05-06 14:32
  cached probe invalidata.

Prossimo /probe e prossimo invoke vedranno il nuovo contenuto.
```

## Listing what already exists before update

If user asked something vague like "aggiorna la sota di X", first call `get_sota_section` for that section to show current content, then ask "vuoi sostituire o aggiungere?". Don't blindly overwrite.

## Error handling

- Initiative not found → list_initiatives.
- Section name invalid → suggest canonical list.
- `custom` without custom_label → ask the user.
- Content > 20k char → truncate or split (rare in v3.2.0; might warrant a separate initiative).

## What NOT to do

- ❌ Don't update SOTA without showing the user the current value first if the user's request is vague.
- ❌ Don't add fake content or invent decisions/dates not in conversation.
- ❌ Don't update from an agent identity without passing `actor_agent` — audit gets `user:<uuid>` which is misleading.
- ❌ Don't bypass the tool to write directly to the DB.
