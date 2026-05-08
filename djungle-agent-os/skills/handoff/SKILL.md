---
name: handoff
description: |
  Create an explicit inter-agent handoff in the Djungle Agent OS. Trigger this skill when the user says "/handoff", "passa a [agent]", "manda un brief a [agent]", "crea un handoff per [agent]", "/handoff [agent]", or any variation of explicitly forwarding context to another agent. This skill calls `create_handoff` MCP tool, persists the handoff in the tenant DB, and writes a markdown mirror to the local filesystem when available. v3.2.2: forza from_agent = session.agent_id (no più "scelta narrativa"), propaga session_id + initiative_id automaticamente, hard-guard sul path mirror.
---

# Handoff — Inter-agent message (v3.2.2)

Create a structured handoff from the **currently active agent in this session** (NEVER a "narratively chosen" different agent) to one or more other agents in the same tenant. The receiving agent will see it in their `pending_handoffs[]` at the next `invoke_agent` call.

## When to trigger

- User says `/handoff <agent>`
- User says "passa questo a Vince", "manda un brief a Lora", "crea un handoff per Iron"
- The active agent suggests "ti conviene un handoff verso X" and the user confirms

## Step-by-step

### 1. Recover the active session context

From the conversation (the `invoke_agent` response payload at session start), recover **MANDATORY**:

- `session.id` (UUID) — `session_id` returned by `invoke_agent`
- `session.agent_id` (e.g. `AGT-3`) — the agent that was invoked
- `session.initiative_id` (UUID, v3.2.0+) — `resolved_initiative.id` from the invoke payload, if present (null if no `initiative_input` was passed)
- `tenant_slug` — for Djungle this is literally `djungle` (NOT the Cowork project name, NOT cwd)

If the user is invoking `/handoff` outside of an active agent session (e.g. directly in a chat without prior `/invoke`), STOP and ask: *"Quale agente sta mandando l'handoff? Devo invocarlo prima."* — then proceed only after `/invoke` has been done.

### 2. Identify destination agent(s)

Extract from the user's message which agent(s) should receive the handoff. Use `list_agents()` to validate names. Multiple destinations OK (max 10).

`to_agents[]` use `agent_id` format (`AGT-N`), NOT names.

### 3. Compose the handoff

Ask the user (or extract from context):

- **`topic`** (≤200 char) — subject line
- **`body`** (markdown, ≤20000 char) — full brief: what to pass, why, what's needed
- **`priority`**: `low` | `normal` (default) | `high` | `urgent` — chiedi se non ovvio
- **`expires_in_days`** (opzionale) — se time-sensitive, suggerisci 7 e conferma

If the user gave only a high-level instruction ("manda un brief a Lora sul pricing"), draft `topic` + `body` yourself, then **show to user** for confirmation before submitting.

### 4. Call `create_handoff` — PARAMETRI FORZATI v3.2.2

```
create_handoff({
  from_agent: "<session.agent_id>",         // FORZATO — vedi sotto
  to_agents: ["AGT-2"],
  topic: "Brief copy investor pitch",
  body: "...",
  priority: "high",
  session_id: "<session.id>",                // FORZATO se sessione attiva
  initiative_slug: "<resolved-slug>",        // FORZATO se session.initiative_id
  expires_in_days: 7
})
```

> **`from_agent` è SEMPRE `session.agent_id`. Punto.** Niente "scelta narrativa" tipo "Iron come vettore strategico verso Set". Se la sessione attiva è con Set (AGT-6), `from_agent = "AGT-6"`. Se l'agente attivo NEL CONTENUTO ragiona dal punto di vista di un altro agente, è una scelta del **body** (firma narrativa), non del FK `from_agent_id` del record. Il record dichiara fattualmente chi ha generato l'handoff durante la session.
>
> **Bug v3.2.0/v3.2.1** (HND-0006/0007/0008): la skill permetteva di scegliere `from_agent` ≠ `session.agent_id` "se narrativamente più appropriato". Generava handoff con attribution falsa. Tracciabilità rotta. Mai più.
>
> **`session_id` è SEMPRE valorizzato** se esiste una sessione attiva. Senza session_id l'handoff è orfano: non puoi rintracciarlo dal session log, non puoi linkare audit, perdi causalità.
>
> **`initiative_slug` è SEMPRE valorizzato** se `session.initiative_id` non è null. Il server fa il lookup slug da uuid. Senza initiative_slug il Probe non vede l'handoff in `recent_handoffs` dell'iniziativa — knowledge persa per quella iniziativa.

Response include:
- `id`, `code` (es. `HND-0042`)
- `file_path` (es. `handoffs/2026-05-12-1430-agt3-to-agt2-investor-pitch.md`) — **path RELATIVO**
- `content_hash` (sha256)
- `mirror_content` (markdown completo con YAML frontmatter)

### 5. Write the filesystem mirror — HARD GUARD v3.2.2

**Solo se filesystem access disponibile** (Cowork desktop, Claude Code). Su mobile/web, skip silently.

#### 5.a — Compute absolute path (HARD GUARD)

Pseudocode:

```python
import os
HOME = os.path.expanduser("~")              # es. /Users/alessandronasi
TENANT = "djungle"                          # per Djungle, sempre questo
BASE = os.path.join(HOME, "Documents", "Claude", f"{TENANT}-context")
ABS_PATH = os.path.join(BASE, file_path)    # file_path è relativo da server

# HARD GUARD #1 — l'absolute path DEVE iniziare con $HOME/Documents/Claude/
assert ABS_PATH.startswith(os.path.join(HOME, "Documents", "Claude") + os.sep), \
    f"Mirror path NOT anchored to ~/Documents/Claude/: {ABS_PATH}"

# HARD GUARD #2 — non devi mai trovarti in $HOME/Documents/handoffs/ o $HOME/handoffs/
forbidden = [
    os.path.join(HOME, "Documents", "handoffs"),
    os.path.join(HOME, "handoffs"),
]
for f in forbidden:
    assert not ABS_PATH.startswith(f + os.sep), \
        f"Mirror path landed in forbidden location: {ABS_PATH}"
```

#### 5.b — Bootstrap dir if missing

```python
os.makedirs(BASE, exist_ok=True)
for sub in ["handoffs","decisions","theses","librarian-reports","inbox","archive"]:
    os.makedirs(os.path.join(BASE, sub), exist_ok=True)
# (eventuale README.md alla radice se manca)
```

`~/Documents/Claude/` esiste sempre (creato da Claude Desktop install). NON ricrearlo.

#### 5.c — Write the file

Scrivi `mirror_content` (la stringa restituita da `create_handoff`) in `ABS_PATH`. UTF-8.

#### 5.d — Verify

Subito dopo il write, verifica che il file esiste **al path absolute corretto**:

```python
assert os.path.isfile(ABS_PATH), f"Write claimed success but file missing: {ABS_PATH}"
# Anche: file size > 0
assert os.path.getsize(ABS_PATH) > 0, "Mirror file empty"
```

Se uno dei guard fallisce → **rollback intenzione**: NON dire all'utente "scritto" — dire "DB ok, mirror filesystem fallito (path guard)" + log esatto path tentato.

> **Bug v3.1.x e v3.2.0** ricorrente: la skill scriveva `mirror_content` su `file_path` raw (es. `handoffs/2026-...md`), che diventava `$CWD/handoffs/2026-...md`. Se cwd era `~/Documents/`, il file finiva in `~/Documents/handoffs/` invece di `~/Documents/Claude/djungle-context/handoffs/`. Il guard `startswith($HOME/Documents/Claude/)` cattura questo errore prima del write.

### 6. Confirm to user

```
Handoff HND-0042 creato.
  Da Vince (AGT-3) → a Lora (AGT-2) · priority high · expires 19/05/2026
  Linked a session SES-INV-... e initiative bp-djungle-holding-2026.
  Topic: Brief copy investor pitch
  Mirror: ~/Documents/Claude/djungle-context/handoffs/2026-05-12-1430-agt3-to-agt2-investor-pitch.md ✓
  Lora lo riceverà in pending_handoffs[] alla prossima /invoke lora.
```

Se `session_id` non disponibile (rara): segnalare esplicitamente "handoff orfano dalla session — solo DB".
Se `initiative_id` non disponibile: segnalare "non linkato a iniziativa — non apparirà in /probe".
Se mirror fallito: segnalare path tentato + ragione.

## Listing existing handoffs

Se l'utente chiede "che handoff ho pendenti?" / "list handoff":

- Per agente specifico: `list_pending_handoffs({to_agent: "AGT-2"})`

## Inspecting history

```
get_handoff_history({ handoff_id: "<uuid>" })
```

Returns timeline `change_type`, `changed_by`, `ts`, `diff_summary`.

## Error handling

- **Agent name not found** → `list_agents` per suggerire validi.
- **Body too long (>20k char)** → split in più handoff o summarize.
- **401** → disconnect+reconnect connector (OAuth flow).
- **Filesystem write fails** o **path guard fails** → log warning specifico, NON dire "scritto", DB resta canonical.

## What NOT to do

- ❌ **NON inventare un `from_agent` diverso da `session.agent_id`.** Mai. Anche se "narrativamente sembrerebbe più appropriato". L'attribution è fattuale, non narrativa.
- ❌ NON omettere `session_id` se la session esiste — perde causalità.
- ❌ NON omettere `initiative_slug` se `session.initiative_id` esiste — handoff diventa invisibile al Probe dell'iniziativa.
- ❌ NON scrivere il mirror a un path custom — sempre `~/Documents/Claude/<tenant_slug>-context/<file_path>`. Se non sei sicuro dove sei, applica i guard `startswith` prima del write.
- ❌ NON inferire `tenant_slug` da `cwd`, dal nome del progetto Cowork, o dal filename. Per Djungle è sempre `djungle`.
- ❌ NON bypassare `create_handoff` per scrivere direttamente sul filesystem — DB è canonical, mirror è sync downstream.
- ❌ NON creare un handoff senza destinazione esplicita — chiedi all'utente.
- ❌ NON fabbricare body — chiedi all'utente o all'agente attivo.
