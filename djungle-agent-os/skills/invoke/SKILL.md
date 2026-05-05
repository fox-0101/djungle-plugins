---
name: invoke
description: |
  Invoke an AI agent from the Djungle Agent OS. Use this skill whenever the user says "invoke [agent name]", "attiva [agent name]", "carica [agent name]", "usa [agent name]", or any variation of loading/activating/starting an agent. Also trigger when the user mentions an agent by name (like "Dean", "Lora", "Focus", "Iron", "Spacey", "Set", "Doc", "Vince", "Bookey") in the context of wanting to work with it, or asks to "start a session with [agent]", "talk to [agent]", "switch to [agent]", or "fammi parlare con [agent]". This skill connects to the Djungle Agent OS MCP server to fetch agent data — no Notion access required.
---

# Invoke — Agent OS Loader

Load an AI agent into the current conversation via the Djungle Agent OS MCP server (v2, multi-tenant). The server handles all communication with the backend — no Notion access is needed.

## How It Works

The plugin includes an MCP server connection (`djungle-agent-os`) that exposes tools to interact with the Agent OS. Use these tools directly.

## CRITICAL — Use ONLY `invoke_agent`

To activate an agent, use **`invoke_agent`** as a single atomic call. **Do NOT decompose into `get_agent` + `create_session`** even if both tools are individually available. `invoke_agent`:

- fetches the agent's system prompt
- opens the session in the same transaction
- returns a **`session_id`** that the `writeback` skill needs to call `close_session` at the end

If you split it into `get_agent` + `create_session`, the resulting `session_id` is independent from the invocation and the writeback flow misalignes. Always prefer `invoke_agent`.

The same applies to listing: use **`list_agents`** as the only entry point — never query Notion directly.

## Step-by-Step Invoke Process

### 1. Identify the agent

Extract the agent name from the user's message. The name might be:
- Exact match: "invoke Dean"
- Lowercase: "invoke dean"
- In Italian: "attiva dean", "carica dean"
- Contextual: "voglio lavorare con Dean"

### 2. Call `invoke_agent` (single call)

The server accepts either `agent_name` (case-insensitive match on the Notion Name or Slug) or `agent_id` (e.g. `AGT-1`). For user-driven invocations, pass `agent_name`:

```
invoke_agent({ agent_name: "Dean" })
```

The server returns:
- `agent_id` — the resolved id (`AGT-N`)
- `name`, `role` — metadata
- `system_prompt` — the full prompt (identity, tone, domain, constraints, output formats, guardrails)
- `session_id`, `session_code` — UUID and code of the session opened automatically. **Store both in your context** for the writeback skill.

If the call fails with "Agent 'xyz' not found", fall back to `list_agents` to suggest valid names — never invent or guess.

### 3. Activate the agent

Once you receive the system prompt from the server:

1. **Adopt the identity** — From this point forward, respond as the agent. Use its name, tone, constraints, and output formats.
2. **Confirm activation** — Send a short activation message in the agent's own voice and style.
3. **Stay in character** for the rest of the conversation.

If the user says "stop", "esci", "torna normale", or "dismiss [agent]", drop the agent persona and return to normal Claude behavior.

## Listing available agents

If the user asks "quali agenti ho?", "lista agenti", "show agents", or similar, use **only** the MCP tool `list_agents`:

```
list_agents()
```

Returns an array of `{ agent_id, name, role, slug, status, domain }`. Present the names (and roles) as a simple list and ask which one they want to invoke.

## Error handling

- **Agent not found** — Server returns `Agent 'xyz' not found`. Call `list_agents` and suggest the available names.
- **401 / Bearer challenge** — The OAuth session expired. Tell the user to **disconnect and reconnect the connector** from Customize → Plugin → Connectors → Djungle agent os; the magic-link flow will re-authenticate them in <1 minute. *No environment variables are involved* in v3+ — never tell the user to check `DJUNGLE_API_KEY` or shell env.
- **`new row violates row-level security policy`** — Server-side bug. Report it to Djungle support, do not retry endlessly.
- **Agent status = Draft** — Proceed but mention it's still in draft.

## What NOT to do

- ❌ Do not call `get_agent` then `create_session` separately to "activate" an agent. Use `invoke_agent`.
- ❌ Do not skip `invoke_agent` and just paste a generic agent prompt — you need the live system prompt from Notion.
- ❌ Do not invent agent names. If unsure, call `list_agents` first.
- ❌ Do not reference `DJUNGLE_API_KEY` or env vars. v3+ uses OAuth magic-link.
