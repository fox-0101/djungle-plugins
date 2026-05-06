---
name: handoff
description: |
  Create an explicit inter-agent handoff in the Djungle Agent OS. Trigger this skill when the user says "/handoff", "passa a [agent]", "manda un brief a [agent]", "crea un handoff per [agent]", "/handoff [agent]", or any variation of explicitly forwarding context to another agent. This skill calls `create_handoff` MCP tool, persists the handoff in the tenant DB, and writes a markdown mirror to the local filesystem when available.
---

# Handoff — Inter-agent message (v3.1.0)

Create a structured handoff from the **currently active agent** (or from the user, if no agent is active) to one or more other agents in the same tenant. The receiving agent will see it in their `pending_handoffs[]` at the next `invoke_agent` call.

## When to trigger

- User says `/handoff <agent>`
- User says "passa questo a Vince", "manda un brief a Lora", "crea un handoff per Iron"
- The active agent suggests "ti conviene un handoff verso X" and the user confirms

## Step-by-step

### 1. Identify destination agent(s)

Extract from the user's message: which agent(s) should receive the handoff. Use `list_agents()` to validate names. Multiple destinations are OK (max 10).

### 2. Identify the source agent

The `from_agent` is:
- The currently active agent in this conversation (preferred), OR
- If no agent is active, ask the user which agent is sending it (or default to the requested context).

`from_agent` and `to_agents[]` use `agent_id` format like `AGT-3`, NOT names.

### 3. Compose the handoff

Ask the user (or extract from context) the following fields:

- **`topic`** (1 line, ≤200 chars): subject line of the handoff
- **`body`** (markdown, ≤20000 chars): full content — what to pass, why, what's needed
- **`priority`**: `low` | `normal` (default) | `high` | `urgent` — surface as a question if non-obvious
- **`expires_in_days`** (optional): if the handoff is time-sensitive, suggest a sensible default (e.g. 7) and confirm
- **`session_id`** (optional, automatic): if the active agent has a `session_id`, pass it
- **`initiative_slug`** (optional, v3.2.0+): leave NULL in v3.1.0

If the user gave only a high-level instruction ("manda un brief a Lora sul pricing"), draft the `topic` and `body` yourself and ask for confirmation before submitting.

### 4. Call `create_handoff`

```
create_handoff({
  from_agent: "AGT-3",
  to_agents: ["AGT-2"],
  topic: "Brief copy investor pitch",
  body: "...",
  priority: "high",
  session_id: "<active session uuid if any>",
  expires_in_days: 7
})
```

Response includes:
- `id`, `code` (e.g. `HND-0042`)
- `file_path` (e.g. `handoffs/2026-05-12-1430-vince-to-lora-investor-pitch.md`)
- `content_hash` (sha256)
- `mirror_content` (full markdown with YAML frontmatter)

### 5. Write the filesystem mirror (best-effort)

If filesystem access is available (Cowork desktop or Claude Code):

**CRITICAL — path resolution rules**:

- The destination is **always absolute**, anchored to `$HOME` (the user's macOS home directory). It is **NEVER** relative to your current working directory, NEVER inside `Projects/`, NEVER guessed from the project name you happen to have open.
- The `[tenant_slug]` is **always** the value of `tenant_slug` returned by the server in `sync_local_mirror`'s `base_path_hint` (or by reading the `code` prefix on the tenant). For Djungle it is literally `djungle` — not the name of the Cowork project.
- If you don't have the tenant_slug from the response, call `sync_local_mirror({types:["handoffs"]})` once to read it from `base_path_hint`. Do NOT infer it from cwd or filename.

Steps:

1. Compute the absolute target: `os.path.expanduser('~/Documents/Claude/<tenant_slug>-context/')` — for Djungle: `~/Documents/Claude/djungle-context/`.
2. The parent `~/Documents/Claude/` already exists (default Claude Desktop folder). Don't recreate it.
3. If `<tenant_slug>-context/` is missing, **bootstrap it**: create the dir + subdirs `handoffs/`, `decisions/`, `theses/`, `librarian-reports/`, `inbox/`, `archive/` + a `README.md`.
4. Write `mirror_content` to `~/Documents/Claude/<tenant_slug>-context/<file_path>`. Use `file_path` (the relative path returned by the server, e.g. `handoffs/2026-05-12-...md`) as-is.
5. If writing fails (permission, disk full), log a warning to the user but don't break — DB is canonical.

If no filesystem access (mobile, web), skip silently.

### 6. Confirm to user

```
Handoff HND-0042 creato.
Da Vince → a Lora · priority high
Topic: Brief copy investor pitch
File mirror: handoffs/2026-05-12-1430-vince-to-lora-investor-pitch.md ✓ scritto
            (oppure: mirror non scritto — solo DB)
Lora lo riceverà alla prossima invocazione.
```

## Listing existing handoffs

If the user asks "che handoff ho pendenti?" / "list handoff":
- For a specific agent: `list_pending_handoffs({to_agent: "AGT-2"})`
- All summary view: not yet exposed as a single tool — list per agent or wait for v3.2.0 dashboard

## Inspecting history

If the user asks "chi ha modificato HND-N?" or "history dell'handoff":

```
get_handoff_history({ handoff_id: "<uuid>" })
```

Returns timeline with `change_type`, `changed_by`, `ts`, `diff_summary`.

## Error handling

- **Agent name not found** → suggest valid agents via `list_agents`.
- **Body too long (>20k chars)** → ask user to split into multiple handoffs or summarize.
- **401** → disconnect+reconnect connector (OAuth flow).
- **Filesystem write fails** → log warning, don't block (DB write is the source of truth).

## What NOT to do

- ❌ Don't create a handoff without an explicit destination agent — always confirm.
- ❌ Don't fabricate body content — ask the user or active agent for the brief.
- ❌ Don't write the file mirror to a custom path — always `~/Documents/Claude/[tenant_slug]-context/<file_path>`.
- ❌ Don't bypass `create_handoff` and write directly to the filesystem — DB is canonical.
