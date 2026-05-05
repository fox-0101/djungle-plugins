---
name: writeback
description: |
  Session writeback command for Agent OS. Use this skill whenever the user says "/writeback", "writeback", "salva sessione", "chiudi sessione", "session log", "wb", or any variation of wanting to save/log what happened during an agent session. This is the WRITEBACK step of the Agent OS flow (INVOKE > CHAT > WRITEBACK > EVOLVE). It analyzes the current conversation, extracts learnings, decisions, performance data, and evolution signals, then saves everything via the Djungle Agent OS MCP server.
---

# Writeback — Agent OS Session Logger

Close the loop on every agent session. Analyze the conversation and persist what matters via the Djungle Agent OS MCP server (v2).

Third step of the Agent OS cycle: **INVOKE > CHAT > WRITEBACK > EVOLVE**.

## What Writeback Captures

Analyze the full conversation and extract:

1. **Learnings & Insight** — New information, surprising connections. Focus on what was *non-obvious*.
2. **Decisions Made** — Concrete choices, direction changes, trade-offs. Include the reasoning.
3. **Performance Assessment** — Quality, efficiency, tone. Rate: `Excellent`, `Good`, `Adequate`, `Needs Improvement`
4. **Feedback Received** — Corrections, praise, frustration signals, preference revelations.
5. **Evolution Signals** — Things suggesting the agent's prompt/knowledge/capabilities should be updated.
6. **Project Status Updates** — Tasks completed, new tasks, blockers, deadlines.

## Step-by-Step Process

### Step 1: Identify the Active Agent and Session

From the conversation history, recover:
- `agent_id` (e.g. `AGT-2`) — the agent that was invoked
- `session_id` (UUID) — returned by `invoke_agent` when the session started

If neither is available, ask the user which agent this session was with and invoke fresh (or skip the session close step).

### Step 2: Analyze the Conversation

Extract content for each of the 6 categories. Be thorough but concise. Write in Italian.

Ask yourself:
- What would be most valuable to know before the *next* session?
- What changed that the agent's profile should reflect?
- What decisions were made that shouldn't be revisited?

### Step 3: Close the Session with a Summary

Use the MCP tool `close_session` with the `session_id` from invoke and a full summary:

```
close_session({
  session_id: "<uuid from invoke_agent>",
  summary: "## Sommario Sessione\n[summary]\n\n## Learnings & Insight\n- [items]\n\n## Decisioni Prese\n- [items]\n\n## Performance\n**Rating:** Good\n[explanation]\n\n## Feedback Ricevuto\n- [items]\n\n## Segnali di Evoluzione\n- [items]\n\n## Stato Progetto\n- [items]"
})
```

### Step 4: Cross-post High-Impact Items to Memory Logs

For each **high-impact** learning, decision, or feedback item, use the MCP tool `write_memory_log`:

```
write_memory_log({
  agent_id: "AGT-2",
  type: "learning",    // one of: learning | decision | context | evolution | observation
  content: "Full context — enough to understand why this matters",
  tags: ["optional", "tags"]
})
```

Pick `type` deliberately:
- `learning` — a non-obvious insight worth remembering
- `decision` — a concrete choice and its reasoning
- `context` — background that informs future sessions
- `evolution` — a signal that the agent's profile should change
- `observation` — passive notes (use sparingly; learnings are usually better)

Only cross-post items genuinely useful for future sessions. Heuristic: "Would I want to see this before the next session?"

### Step 5: Confirm to User

Present a summary:

```
Writeback completato per [Agent Name]

Session chiusa: SES-INV-...
Performance: [Rating]
[N] items scritti in Memory Logs
Evoluzione: [Si/No]
```

## Important Notes

- Write in Italian for content, English for tool parameter values (`type: "learning"` not `"apprendimento"`)
- The session summary is the single source of truth — be accurate, not flattering
- Cross-posting to Memory Logs is selective — quality over quantity
- If the MCP server returns 401 / is not connected, the OAuth session expired. Tell the user to **disconnect and reconnect the connector** from Customize → Plugin → Connectors → Djungle agent os; the magic-link flow will re-authenticate in <1 minute. *No environment variables involved* in v3+.
- If `session_id` is unknown (the user invoked the agent outside of this Cowork session, e.g. on Notion v1), skip step 3 and only write `write_memory_log` entries — they are independent of sessions.
