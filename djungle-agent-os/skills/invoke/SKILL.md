---
name: invoke
description: |
  Invoke an AI agent from the Djungle Agent OS. Use this skill whenever the user says "invoke [agent name]", "attiva [agent name]", "carica [agent name]", "usa [agent name]", or any variation of loading/activating/starting an agent. Also trigger when the user mentions an agent by name (like "Dean", "Lora", "Focus", "Iron", "Spacey", "Set", "Doc", "Vince", "Bookey") in the context of wanting to work with it, or asks to "start a session with [agent]", "talk to [agent]", "switch to [agent]", or "fammi parlare con [agent]". This skill connects to the Djungle Agent OS MCP server to fetch agent data — no Notion access required.
---

# Invoke — Agent OS Loader

Load an AI agent into the current conversation via the Djungle Agent OS MCP server (v2, multi-tenant). The server handles all communication with the backend — no Notion access is needed.

## How It Works

The plugin includes an MCP server connection (`djungle-agent-os`) that exposes tools to interact with the Agent OS. Use these tools directly.

## Step-by-Step Invoke Process

### 1. Identify the Agent

Extract the agent name from the user's message. The name might be:
- Exact match: "invoke Dean"
- Lowercase: "invoke dean"
- In Italian: "attiva dean", "carica dean"
- Contextual: "voglio lavorare con Dean"

### 2. Call invoke_agent

Use the MCP tool `invoke_agent` with the agent's name. The server accepts either `agent_name` (case-insensitive match on the Notion Name or Slug) or `agent_id` (e.g. `AGT-1`). For user-driven invocations, pass `agent_name`:

```
invoke_agent({ agent_name: "Dean" })
```

The server returns an object with:
- `agent_id` — the resolved id (`AGT-N`)
- `name`, `role` — metadata
- `system_prompt` — the full prompt (identity, tone, domain, constraints, output formats, guardrails)
- `session_id`, `session_code` — UUID and code of the session opened automatically. **Store both in your context**: the writeback skill uses `session_id` to close the session at the end.

### 3. Activate the Agent

Once you receive the system prompt from the server:

1. **Adopt the identity** — From this point forward, respond as the agent. Use its name, tone, constraints, and output formats.
2. **Confirm activation** — Send a short activation message in the agent's own voice and style.
3. **Stay in character** for the rest of the conversation.

If the user says "stop", "esci", "torna normale", or "dismiss [agent]", drop the agent persona and return to normal Claude behavior.

## Listing Available Agents

If the user asks "quali agenti ho?", "lista agenti", "show agents", or similar, use the MCP tool `list_agents`:

```
list_agents()
```

Returns an array of `{ agent_id, name, role, slug, status, domain }`. Present the names (and roles) as a simple list and ask which one they want to invoke.

## Error Handling

- **Agent not found** — Server returns `Agent 'xyz' not found`. Call `list_agents` and suggest the available names.
- **401 / connection error** — User's API key or user id is missing or invalid. Ask them to check `DJUNGLE_API_KEY` and `DJUNGLE_USER_ID` in their shell environment (read by the MCP client at startup).
- **Agent status = Draft** — Proceed but mention it's still in draft.
