---
name: invoke
description: |
  Invoke an AI agent from the Djungle Agent OS. Use this skill whenever the user says "invoke [agent name]", "attiva [agent name]", "carica [agent name]", "usa [agent name]", or any variation of loading/activating/starting an agent. Also trigger when the user mentions an agent by name (like "Dean", "Lora", "Focus", "Iron", "Spacey", "Set", "Doc", "Vince", "Bookey") in the context of wanting to work with it, or asks to "start a session with [agent]", "talk to [agent]", "switch to [agent]", or "fammi parlare con [agent]". This skill connects to the Djungle Agent OS MCP server to fetch agent data and run the pre-flight protocol.
---

# Invoke — Agent OS Loader (v3.2.0)

Load an AI agent with **pre-flight protocol**, **pending handoff handling**, and **initiative resolution + context probe** (v3.2.0+).

## CRITICAL — Use ONLY `invoke_agent`

Use **`invoke_agent`** as a single atomic call. **Do NOT decompose** into `get_agent` + `create_session` + `resolve_initiative` + `probe_initiative_context`. The server orchestrates the whole flow.

`invoke_agent` (v3.2.0) returns:

- `agent_id`, `name`, `role`, `system_prompt`
- `session_id`, `session_code` — needed by `writeback` skill (saved into the conversation context)
- `pending_handoffs[]` — handoffs directed at this agent
- `preflight_status: 'ok'`
- **`resolved_initiative`** — `{id, slug, name}` if the user mentioned an initiative, else null
- **`probe_payload`** — full context (SOTA, recent_sessions, pending_handoffs, references, carenze_detected) when resolved_initiative is set
- **`dialog_required`** — true if the resolver needs a user choice (ambiguous match or new-initiative classifier hit). When set, `session_id` is empty — DO NOT yet adopt the agent identity, ask the user first and re-call invoke_agent with the confirmed slug.

## Step-by-step

### 1. Identify the agent

Extract the agent name from the user's message: "invoke Dean", "attiva dean", "voglio lavorare con Dean", etc.

### 2. Pre-flight step 1: read CLAUDE.md if present

**Before calling `invoke_agent`**, if you have filesystem access (Cowork desktop or Claude Code), read `CLAUDE.md` from the current project root. If present, keep its content available — you'll inject it as opening context for the agent.

If absent, note it: at activation time, mention "non vedo CLAUDE.md, vuoi che ti aiuti a compilarlo?" so the user can decide whether to fix or proceed.

If filesystem is not accessible (mobile, web), skip silently — the agent runs without project context (the MOD-preflight-check module on the agent prompt handles soft mode).

### 2.5. Initiative resolution (v3.2.0+)

**Extract the initiative the user wants to work on**, if any. Patterns to recognize:

- "lavoriamo su X" / "let's work on X"
- "su X" come tail della frase ("invoke Dean su Storytelling AI")
- "il progetto X" / "the project X"
- "X" tra virgolette o in maiuscolo dopo l'agent name
- "comunicazione del Y" → riferimento implicito a Y

If found, pass it as `initiative_input` (free text, NOT a slug — the server resolves).

If no clear initiative is mentioned, omit `initiative_input` and the agent runs without initiative context. That's fine — the user can switch later with `/sota <slug>` or by referencing it in the next prompt.

### 3. Call `invoke_agent` (single call)

```
invoke_agent({ agent_name: "Dean", initiative_input: "Storytelling AI" })
```

### 3.5. Handle the resolver dialog (if any)

If `result.dialog_required === true`:

- `dialog_payload.kind === 'ambiguous'` → show the candidates from `dialog_payload.options[]` (slug, name, reason). Ask user to pick. Re-call `invoke_agent({agent_name, initiative_input: <chosen-slug>})`.
- `dialog_payload.kind === 'confirm'` → ask "È <name> (<slug>)?" Yes → re-call with that slug. No → ask user what they meant.
- `dialog_payload.kind === 'not_found_with_classifier'` → the classifier suggested it might be a new initiative. Show its message + classifier reasoning. If user says "yes, create it", call `create_initiative({slug, name, type, domain_slug})` first, then re-call invoke_agent with the new slug.
- `dialog_payload.kind === 'not_found_no_match'` → no match and no classifier insight. Ask user if they want to skip (re-call `invoke_agent` without `initiative_input`) or create a new initiative manually.

**Do not adopt the agent identity until the dialog is resolved.** No session is created during dialog turns.

### 3.6. Probe payload injection (when resolved)

If `result.probe_payload` is non-null:

- It contains `initiative` (full row), `domain`, `sota[]` (canonical sections), `recent_sessions[]`, `pending_handoffs[]`, `recent_memory_logs[]`, `references[]` (related initiatives with current_state snippet), `carenze_detected[]` (4 types: missing_sota_section, stale_initiative, open_loop_old, missing_kpi).
- Inject it into the agent's working memory as a "Initiative Context" block prepended to the conversation, after CLAUDE.md and before the user's task.
- If `carenze_detected[]` has entries with severity `warning`, the agent SHOULD mention them in 1 line ("vedo open_loop X aperto da N giorni") before proceeding to the task. The MOD-preflight-check Notion module handles this — just pass the carenze through.

### 4. Surface pending handoffs (if any)

If `result.pending_handoffs` is non-empty, **before** the agent's first user-facing reply, show a brief inline summary:

```
Pre-flight ok. Ho N handoff pending:

- HND-NNN · priority [high|normal|low|urgent] · 2 ore fa
  Da [from_agent] · Topic: [topic]
[...]

Li processo prima del tuo task o dopo?
```

Wait for the user's choice. If they say "prima", load each pending handoff body (call `list_pending_handoffs({to_agent})` to get full body, or use the IDs from `pending_handoffs[]` and call the relevant tool); after processing each, call `acknowledge_handoff({handoff_id, consumed_by_agent, status: "consumed", notes})`.

If "dopo" or "ignora per ora", just acknowledge silently and proceed to the user's task.

### 5. Activate the agent

Adopt the agent identity:
- Use the `system_prompt` returned by `invoke_agent` as the agent's identity.
- If you have CLAUDE.md content, **prepend** it as a "Project Context" section to the agent's working memory.
- If you have user-provided instructions earlier in the conversation, merge them as "User Instructions".
- Confirm activation in the agent's voice (1 line), then either process pending handoffs or move to the user task.

If the user says "stop", "esci", "torna normale", "dismiss", drop the persona.

## Listing available agents

User asks "quali agenti", "lista agenti": call `list_agents()` — only entry point, never query Notion directly. Present names + roles, ask which.

## Filesystem mirror (optional, Cowork desktop / Claude Code)

If you have filesystem access AND the activated agent (or the user) creates a handoff via `create_handoff(...)`, the response includes `file_path` (relative) and `mirror_content` (full markdown). Write it to disk under the standard Claude documents folder.

**CRITICAL — path is absolute from `$HOME`, never relative to cwd**:

```
~/Documents/Claude/<tenant_slug>-context/<file_path>
```

- `<tenant_slug>` = the value returned by the server (e.g. `djungle`). NOT the name of the Cowork project you have open. NOT inferred from cwd. Call `sync_local_mirror` once to read `base_path_hint` if unsure.
- The parent `~/Documents/Claude/` already exists from Claude Desktop install — don't recreate it.
- Bootstrap `<tenant_slug>-context/` (with `handoffs/`, `decisions/`, `theses/`, `librarian-reports/`, `inbox/`, `archive/` + `README.md`) only the first time it's missing.

```
~/Documents/Claude/[tenant_slug]-context/
├── handoffs/
├── decisions/   (v3.2.0+)
├── theses/      (v3.2.0+)
└── README.md
```

Skip silently on mobile/web — DB write is canonical, file mirror is best-effort bonus.

## Error handling

- **Agent not found** → `list_agents` and suggest valid names.
- **401 / Bearer challenge** → OAuth session expired. Disconnect + reconnect the connector (Customize → Plugin → Connectors). No env vars in v3+.
- **`row-level security policy`** → server bug, report to Djungle support, no retry loop.
- **Agent status = Draft** → proceed but mention it.

## What NOT to do

- ❌ Decompose `invoke_agent` into `get_agent` + `create_session`.
- ❌ Skip `invoke_agent` and paste a generic prompt.
- ❌ Invent agent names. Use `list_agents`.
- ❌ Reference `DJUNGLE_API_KEY` or env vars. v3+ uses OAuth.
- ❌ Process pending handoffs without surfacing them to the user — always ask.
- ❌ Block on filesystem write failure: it's optional.
