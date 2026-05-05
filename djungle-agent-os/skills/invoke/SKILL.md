---
name: invoke
description: |
  Invoke an AI agent from the Djungle Agent OS. Use this skill whenever the user says "invoke [agent name]", "attiva [agent name]", "carica [agent name]", "usa [agent name]", or any variation of loading/activating/starting an agent. Also trigger when the user mentions an agent by name (like "Dean", "Lora", "Focus", "Iron", "Spacey", "Set", "Doc", "Vince", "Bookey") in the context of wanting to work with it, or asks to "start a session with [agent]", "talk to [agent]", "switch to [agent]", or "fammi parlare con [agent]". This skill connects to the Djungle Agent OS MCP server to fetch agent data and run the pre-flight protocol.
---

# Invoke — Agent OS Loader (v3.1.0)

Load an AI agent into the current conversation via the Djungle Agent OS MCP server, with **pre-flight protocol** and **pending handoff handling**.

## CRITICAL — Use ONLY `invoke_agent`

To activate an agent use **`invoke_agent`** as a single atomic call. **Do NOT decompose into `get_agent` + `create_session`.** `invoke_agent` v3.1.0 returns:

- `agent_id`, `name`, `role`, `system_prompt`
- `session_id`, `session_code` — needed by `writeback` skill
- **`pending_handoffs[]`** — handoffs directed at this agent waiting to be processed
- **`preflight_status: 'ok'`** — server-side preflight signal

If you split it, `session_id` becomes orphan, `pending_handoffs` are not auto-loaded, and the writeback flow misalignes.

## Step-by-step

### 1. Identify the agent

Extract the agent name from the user's message: "invoke Dean", "attiva dean", "voglio lavorare con Dean", etc.

### 2. Pre-flight step 1: read CLAUDE.md if present

**Before calling `invoke_agent`**, if you have filesystem access (Cowork desktop or Claude Code), read `CLAUDE.md` from the current project root. If present, keep its content available — you'll inject it as opening context for the agent.

If absent, note it: at activation time, mention "non vedo CLAUDE.md, vuoi che ti aiuti a compilarlo?" so the user can decide whether to fix or proceed.

If filesystem is not accessible (mobile, web), skip silently — the agent runs without project context (the MOD-preflight-check module on the agent prompt handles soft mode).

### 3. Call `invoke_agent` (single call)

```
invoke_agent({ agent_name: "Dean" })
```

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

If you have filesystem access AND the activated agent (or the user) creates a handoff via `create_handoff(...)`, the response includes `file_path` (relative) and `mirror_content` (full markdown). Write it to disk:

```
~/[tenant_slug]-context/handoffs/<file_path basename>
```

The `tenant_slug` comes from the user's tenant — derive it from the agent_os response or ask once. Bootstrap the directory if it doesn't exist:

```
~/[tenant_slug]-context/
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
